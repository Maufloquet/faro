"use strict";

/**
 * Scheduler que ingere ocorrências do Fogo Cruzado e grava em Firestore.
 *
 * Frequência: a cada 30 minutos (alinhado ao §5.2 do relatório v3).
 * Estado: BA (piloto). Outros estados habilitados via env.
 *
 * Estratégia de dedup:
 *   - id da ocorrência do Fogo Cruzado vira docId no Firestore
 *   - upsert idempotente (set com merge)
 *   - expiresAt = date + 24h para uso na Fase 1 (depois movemos lifecycle pra
 *     função separada de housekeeping)
 */

const admin = require("firebase-admin");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { logger } = require("firebase-functions/v2");
const ngeohash = require("ngeohash");
const { authedFetch } = require("./fogoCruzadoAuth");
const { buildEventKey } = require("./eventKey");
const { runWithHealth } = require("./jobHealth");
const {
  embedTexts,
  EMBEDDING_DIM,
  EMBEDDING_PROVIDER,
} = require("./embedClient");
const { findSemanticDuplicate } = require("./semanticDedup");

/** Mesma janela do newsIngest — coerência cross-source. */
const DEDUP_WINDOW_HOURS = 6;
const CORROBORATION_WEIGHT_BOOST = 0.05;
const MAX_CORROBORATED_WEIGHT = 0.95;

const STATE_IDS = {
  BA: "d3a9b545-7056-4dc6-9b68-ce320c9edffc",
  PE: "813ca36b-91e3-4a18-b408-60b27a1942ef",
  RJ: "b112ffbe-17b3-4ad0-8f2a-2038745d1d14",
  PA: "2a98a020-3815-45d7-a6f6-6de2119eba8b",
};

const ENABLED_STATES = (process.env.ENABLED_STATES || "BA").split(",").map((s) => s.trim());

const PAGE_SIZE = 100;
const SOURCE = "fogo_cruzado";
const SOURCE_WEIGHT = 0.7;
// TTL gravado por doc. App filtra por janela temporal no cliente
// (TimeWindow chips), então 30 dias dá folga pra cobrir o "30 dias" do
// filtro mais largo. Cleanup periódico fica pra função separada.
const TTL_HOURS = 24 * 30;

exports.syncFogoCruzado = onSchedule(
  {
    schedule: "every 30 minutes",
    timeZone: "America/Bahia",
    region: "southamerica-east1",
    memory: "256MiB",
    timeoutSeconds: 120,
    secrets: ["FOGO_CRUZADO_EMAIL", "FOGO_CRUZADO_PASSWORD", "GEMINI_API_KEY"],
  },
  async () => runWithHealth("syncFogoCruzado", async () => {
    const db = admin.firestore();
    const totals = {};
    let itemsWritten = 0;

    for (const stateAbbr of ENABLED_STATES) {
      const stateId = STATE_IDS[stateAbbr];
      if (!stateId) {
        logger.warn(`Estado ${stateAbbr} não mapeado, pulando.`);
        continue;
      }

      const result = await syncState(db, stateAbbr, stateId);
      totals[stateAbbr] = result;
      itemsWritten += result.upserted + result.corroborated;
      logger.info(`Sync ${stateAbbr}: ${result.upserted} ocorrências`);
    }

    logger.info("Sync Fogo Cruzado concluído", { totals });
    return { itemsWritten };
  })
);

/**
 * Mapeia um item bruto da API do Fogo Cruzado pro shape de Firestore.
 * Função pura — retorna `null` quando o item não tem lat/lng utilizável.
 *
 * `date` e `expiresAt` saem como `Date`; o caller converte pra Timestamp.
 */
function prepareOccurrenceDoc(item, stateAbbr, ttlMs) {
  if (!item || !item.latitude || !item.longitude) return null;

  const date = new Date(item.date);
  const expiresAt = new Date(date.getTime() + ttlMs);
  const geohash = ngeohash.encode(item.latitude, item.longitude, 8);
  const city = item.city?.name || null;
  const neighborhood = item.neighborhood?.name || null;
  const mainReason = item.contextInfo?.mainReason?.name || null;

  return {
    docId: item.id,
    fields: {
      latitude: Number(item.latitude),
      longitude: Number(item.longitude),
      geohash,
      date,
      expiresAt,
      state: item.state?.name || stateAbbr,
      city,
      neighborhood,
      mainReason,
      eventKey: buildEventKey({ city, neighborhood, mainReason }),
      policeAction: !!item.policeAction,
      agentPresence: !!item.agentPresence,
      source: SOURCE,
      weight: SOURCE_WEIGHT,
      externalId: item.id,
      documentNumber: item.documentNumber || null,
    },
  };
}

/**
 * Procura doc existente em /occurrences com mesma eventKey em ±DEDUP_WINDOW_HOURS.
 * Critério é source-agnostic: pode ser doc de media ou de outra ingestão do FC.
 */
async function findCorroboratableDoc(db, eventKey, pubDate) {
  if (!eventKey) return null;
  const windowMs = DEDUP_WINDOW_HOURS * 60 * 60 * 1000;
  const since = new Date(pubDate.getTime() - windowMs);
  const until = new Date(pubDate.getTime() + windowMs);
  const snap = await db
    .collection("occurrences")
    .where("eventKey", "==", eventKey)
    .where("date", ">=", admin.firestore.Timestamp.fromDate(since))
    .where("date", "<=", admin.firestore.Timestamp.fromDate(until))
    .limit(1)
    .get();
  return snap.empty ? null : snap.docs[0];
}

async function syncState(db, stateAbbr, stateId) {
  const data = await authedFetch("/occurrences", {
    idState: stateId,
    take: PAGE_SIZE,
    order: "DESC",
    page: 1,
  });
  const items = data.data || [];

  const ttlMs = TTL_HOURS * 60 * 60 * 1000;
  let upserted = 0;
  let corroborated = 0;

  // Embeddings em batch antes do loop pra economizar chamadas e cobrir
  // todo o lote num único `batchEmbedContents`. Vetores ficam alinhados
  // por índice com o `prepareOccurrenceDoc` resultante; itens sem geo
  // viram null. Falha graciosa: erro de Gemini deixa vetores=[] e o
  // pipeline cai pra dedup por eventKey.
  const prepareds = items.map((o) => prepareOccurrenceDoc(o, stateAbbr, ttlMs));
  const embeddings = await embedItemsSafe(prepareds);

  for (let i = 0; i < items.length; i++) {
    const prepared = prepareds[i];
    if (!prepared) continue;
    const embedding = embeddings[i];

    // Skip dedupe se o doc canônico do FC já existe — idempotência por id externo.
    const ownRef = db.collection("occurrences").doc(prepared.docId);
    const ownSnap = await ownRef.get();

    if (!ownSnap.exists) {
      // Procura por evento equivalente em outra fonte (ex.: matéria de
      // jornal que já cobriu esse tiroteio). Tenta primeiro por
      // similaridade semântica via embedding; cai pra eventKey quando
      // não há vetor ou o índice ainda está building.
      let existing = null;
      if (embedding) {
        try {
          existing = await findSemanticDuplicate(
            db,
            embedding,
            prepared.fields.date,
            { windowHours: DEDUP_WINDOW_HOURS, excludeId: prepared.docId },
          );
        } catch (e) {
          logger.warn(`FC findNearest falhou, caindo pra eventKey: ${e.message}`);
        }
      }
      if (!existing) {
        existing = await findCorroboratableDoc(
          db,
          prepared.fields.eventKey,
          prepared.fields.date,
        );
      }
      if (existing && existing.id !== prepared.docId) {
        const data = existing.data();
        const currentWeight = typeof data.weight === "number" ? data.weight : 0.5;
        await existing.ref.update({
          corroborations: admin.firestore.FieldValue.arrayUnion({
            source: SOURCE,
            externalId: prepared.docId,
            mainReason: prepared.fields.mainReason,
            addedAt: new Date(),
          }),
          corroborationCount: admin.firestore.FieldValue.increment(1),
          weight: Math.min(MAX_CORROBORATED_WEIGHT, currentWeight + CORROBORATION_WEIGHT_BOOST),
          expiresAt: admin.firestore.Timestamp.fromDate(
            new Date(Math.max(
              data.expiresAt?.toMillis?.() ?? 0,
              prepared.fields.expiresAt.getTime(),
            )),
          ),
          lastCorroboratedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        corroborated++;
        continue;
      }
    }

    const docPayload = {
      ...prepared.fields,
      date: admin.firestore.Timestamp.fromDate(prepared.fields.date),
      expiresAt: admin.firestore.Timestamp.fromDate(prepared.fields.expiresAt),
      corroborationCount: ownSnap.exists ? (ownSnap.data().corroborationCount ?? 0) : 0,
      ingestedAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    if (embedding) {
      docPayload.embedding = admin.firestore.FieldValue.vector(embedding);
      docPayload.embeddingProvider = EMBEDDING_PROVIDER;
      docPayload.embeddingDim = EMBEDDING_DIM;
    }
    await ownRef.set(docPayload, { merge: true });
    upserted++;
  }

  return { fetched: items.length, upserted, corroborated };
}

/**
 * Texto canônico pra embedar um relato do Fogo Cruzado. Como FC tem
 * estrutura padronizada (não texto livre), montamos uma frase curta
 * descritiva que casa com o conteúdo editorial das matérias — assim
 * o cross-source dedup funciona contra notícias do mesmo evento.
 *
 * Pura: testável sem rede.
 */
function fogoCruzadoCanonicalText(prepared) {
  if (!prepared) return null;
  const f = prepared.fields;
  const parts = [
    f.mainReason || "Relato",
    f.neighborhood ? `em ${f.neighborhood}` : null,
    f.city ? `, ${f.city}` : null,
    f.policeAction ? "com ação policial" : null,
    f.agentPresence ? "com agentes presentes" : null,
  ].filter(Boolean);
  const text = parts.join(" ").trim();
  return text.length > 0 ? text.slice(0, 2000) : null;
}

/**
 * Embeda em batch todos os textos canônicos do lote. Retorna array
 * alinhado por índice com `prepareds`. Itens sem texto ou sem geo
 * recebem `null`. Falha de Gemini propaga `null` pra todos sem derrubar
 * o sync.
 */
async function embedItemsSafe(prepareds) {
  const out = new Array(prepareds.length).fill(null);
  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) {
    logger.warn("FC: GEMINI_API_KEY ausente — sync sem embeddings");
    return out;
  }
  const indices = [];
  const texts = [];
  for (let i = 0; i < prepareds.length; i++) {
    const text = fogoCruzadoCanonicalText(prepareds[i]);
    if (text) {
      indices.push(i);
      texts.push(text);
    }
  }
  if (texts.length === 0) return out;
  try {
    const vectors = await embedTexts(texts, { apiKey });
    for (let k = 0; k < vectors.length; k++) {
      const v = vectors[k];
      if (v && v.length === EMBEDDING_DIM) out[indices[k]] = v;
    }
  } catch (e) {
    logger.warn(`FC embed batch falhou (${texts.length} itens): ${e.message}`);
  }
  return out;
}

exports._internal = {
  prepareOccurrenceDoc,
  findCorroboratableDoc,
  fogoCruzadoCanonicalText,
  DEDUP_WINDOW_HOURS,
};
