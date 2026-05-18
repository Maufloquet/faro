"use strict";

/**
 * Backfill histórico do Fogo Cruzado — one-shot, manual.
 *
 * O sync periódico (syncFogoCruzado) pega só os 100 mais recentes por
 * estado a cada 30min. Isso popula o "agora" mas não cria histórico —
 * docs com mais de 30 dias vão expirar e não tem como reaver.
 *
 * Esta função faz o oposto: paginação completa de 90 dias para trás,
 * por estado, e escreve tudo de uma vez no Firestore. Roda 1x, à mão.
 *
 * Como invocar:
 *   curl -X POST -H "Authorization: Bearer <token>" <function-url>
 *   ou pelo Console Cloud Functions → "Testar".
 *
 * Idempotente: usa o externalId do Fogo Cruzado como docId. Se rodar
 * 2x não duplica nada, só refresha os campos.
 *
 * Custo estimado: ~500 a 1500 docs Firestore write @ R$ 0,01/100k =
 * centavos. LLM nenhum (não passa por classificação).
 */

const admin = require("firebase-admin");
const { onRequest } = require("firebase-functions/v2/https");
const { logger } = require("firebase-functions/v2");
const ngeohash = require("ngeohash");
const { authedFetch } = require("./fogoCruzadoAuth");
const { buildEventKey } = require("./eventKey");

const STATE_IDS = {
  BA: "d3a9b545-7056-4dc6-9b68-ce320c9edffc",
  PE: "813ca36b-91e3-4a18-b408-60b27a1942ef",
  RJ: "b112ffbe-17b3-4ad0-8f2a-2038745d1d14",
  PA: "2a98a020-3815-45d7-a6f6-6de2119eba8b",
};

const PAGE_SIZE = 100;
const SOURCE = "fogo_cruzado";
const SOURCE_WEIGHT = 0.7;
const HISTORY_DAYS = 90;
const TTL_DAYS = 30;

exports.backfillFogoCruzado = onRequest(
  {
    region: "southamerica-east1",
    memory: "512MiB",
    timeoutSeconds: 540,
    secrets: ["FOGO_CRUZADO_EMAIL", "FOGO_CRUZADO_PASSWORD"],
    // invoker: "private" por default — só admins do projeto podem chamar.
  },
  async (req, res) => {
    const states = (req.query.states || "BA").split(",").map((s) => s.trim());
    const daysParam = parseInt(req.query.days || HISTORY_DAYS, 10);
    const days = Math.max(1, Math.min(180, daysParam)); // cap a 180

    const finalDate = new Date();
    const initialDate = new Date(finalDate.getTime() - days * 24 * 60 * 60 * 1000);

    const stats = {
      requestedStates: states,
      daysRange: days,
      from: initialDate.toISOString(),
      to: finalDate.toISOString(),
      byState: {},
      totalWritten: 0,
    };

    const db = admin.firestore();

    for (const stateAbbr of states) {
      const stateId = STATE_IDS[stateAbbr];
      if (!stateId) {
        stats.byState[stateAbbr] = { error: "estado desconhecido" };
        continue;
      }

      try {
        const result = await backfillState(db, stateAbbr, stateId, initialDate, finalDate);
        stats.byState[stateAbbr] = result;
        stats.totalWritten += result.written;
      } catch (e) {
        stats.byState[stateAbbr] = { error: e.message };
      }
    }

    logger.info("Backfill Fogo Cruzado concluído", stats);
    res.status(200).json(stats);
  }
);

async function backfillState(db, stateAbbr, stateId, initialDate, finalDate) {
  const ttlMs = TTL_DAYS * 24 * 60 * 60 * 1000;
  let page = 1;
  let totalWritten = 0;
  let totalFetched = 0;
  const maxPages = 50; // teto de segurança: 50 * 100 = 5000 docs por estado

  while (page <= maxPages) {
    const params = {
      idState: stateId,
      take: PAGE_SIZE,
      order: "DESC",
      page,
      initialdate: toApiDate(initialDate),
      finaldate: toApiDate(finalDate),
    };

    const data = await authedFetch("/occurrences", params);
    const items = data.data || [];
    if (items.length === 0) break;
    totalFetched += items.length;

    // Batch write — Firestore aceita até 500 ops/batch
    let batch = db.batch();
    let inBatch = 0;
    for (const o of items) {
      if (!o.latitude || !o.longitude) continue;
      const ref = db.collection("occurrences").doc(o.id);
      const date = new Date(o.date);
      const expiresAt = new Date(date.getTime() + ttlMs);
      const geohash = ngeohash.encode(Number(o.latitude), Number(o.longitude), 8);
      const city = o.city?.name || null;
      const neighborhood = o.neighborhood?.name || null;
      const mainReason = o.contextInfo?.mainReason?.name || null;

      batch.set(
        ref,
        {
          latitude: Number(o.latitude),
          longitude: Number(o.longitude),
          geohash,
          date: admin.firestore.Timestamp.fromDate(date),
          expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
          state: o.state?.name || stateAbbr,
          city,
          neighborhood,
          mainReason,
          // eventKey grava pra que o dedupe do scheduler diário consiga
          // achar matches contra dados históricos. Backfill em si é
          // one-shot e usa id externo do FC como docId, então é
          // idempotente por construção; mas docs futuros (matéria de
          // jornal cobrindo evento dentro da janela) precisam achar isso.
          eventKey: buildEventKey({ city, neighborhood, mainReason }),
          policeAction: !!o.policeAction,
          agentPresence: !!o.agentPresence,
          source: SOURCE,
          weight: SOURCE_WEIGHT,
          externalId: o.id,
          documentNumber: o.documentNumber || null,
          backfilled: true,
          ingestedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
      inBatch++;
      totalWritten++;

      if (inBatch >= 400) {
        await batch.commit();
        batch = db.batch();
        inBatch = 0;
      }
    }
    if (inBatch > 0) await batch.commit();

    logger.info(`${stateAbbr} page ${page}: fetched=${items.length} written-so-far=${totalWritten}`);

    if (items.length < PAGE_SIZE) break;
    page++;
  }

  return { pages: page - (page > maxPages ? 0 : 1), fetched: totalFetched, written: totalWritten };
}

function toApiDate(d) {
  // Fogo Cruzado espera YYYY-MM-DD
  return d.toISOString().slice(0, 10);
}
