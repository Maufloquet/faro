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
    secrets: ["FOGO_CRUZADO_EMAIL", "FOGO_CRUZADO_PASSWORD"],
  },
  async () => {
    const db = admin.firestore();
    const totals = {};

    for (const stateAbbr of ENABLED_STATES) {
      const stateId = STATE_IDS[stateAbbr];
      if (!stateId) {
        logger.warn(`Estado ${stateAbbr} não mapeado, pulando.`);
        continue;
      }

      const result = await syncState(db, stateAbbr, stateId);
      totals[stateAbbr] = result;
      logger.info(`Sync ${stateAbbr}: ${result.upserted} ocorrências`);
    }

    logger.info("Sync Fogo Cruzado concluído", { totals });
  }
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

  for (const o of items) {
    const prepared = prepareOccurrenceDoc(o, stateAbbr, ttlMs);
    if (!prepared) continue;

    // Skip dedupe se o doc canônico do FC já existe — idempotência por id externo.
    const ownRef = db.collection("occurrences").doc(prepared.docId);
    const ownSnap = await ownRef.get();

    if (!ownSnap.exists) {
      // Procura por evento equivalente em outra fonte (ex.: matéria de
      // jornal que já cobriu esse tiroteio). Se achou, anexa corroboração
      // ao doc existente em vez de criar uma duplicata aqui.
      const existing = await findCorroboratableDoc(
        db,
        prepared.fields.eventKey,
        prepared.fields.date,
      );
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

    await ownRef.set(
      {
        ...prepared.fields,
        date: admin.firestore.Timestamp.fromDate(prepared.fields.date),
        expiresAt: admin.firestore.Timestamp.fromDate(prepared.fields.expiresAt),
        corroborationCount: ownSnap.exists ? (ownSnap.data().corroborationCount ?? 0) : 0,
        ingestedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
    upserted++;
  }

  return { fetched: items.length, upserted, corroborated };
}

exports._internal = {
  prepareOccurrenceDoc,
  findCorroboratableDoc,
  DEDUP_WINDOW_HOURS,
};
