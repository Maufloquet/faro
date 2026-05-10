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
const TTL_HOURS = 24;

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

async function syncState(db, stateAbbr, stateId) {
  const data = await authedFetch("/occurrences", {
    idState: stateId,
    take: PAGE_SIZE,
    order: "DESC",
    page: 1,
  });
  const items = data.data || [];

  const now = Date.now();
  const ttlMs = TTL_HOURS * 60 * 60 * 1000;

  const batch = db.batch();
  let upserted = 0;

  for (const o of items) {
    if (!o.latitude || !o.longitude) continue;

    const ref = db.collection("occurrences").doc(o.id);
    const date = new Date(o.date);
    const expiresAt = new Date(date.getTime() + ttlMs);

    if (expiresAt.getTime() < now) continue;

    const geohash = ngeohash.encode(o.latitude, o.longitude, 8);

    batch.set(
      ref,
      {
        latitude: Number(o.latitude),
        longitude: Number(o.longitude),
        geohash,
        date: admin.firestore.Timestamp.fromDate(date),
        expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
        state: o.state?.name || stateAbbr,
        city: o.city?.name || null,
        neighborhood: o.neighborhood?.name || null,
        mainReason: o.contextInfo?.mainReason?.name || null,
        policeAction: !!o.policeAction,
        agentPresence: !!o.agentPresence,
        source: SOURCE,
        weight: SOURCE_WEIGHT,
        externalId: o.id,
        documentNumber: o.documentNumber || null,
        ingestedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
    upserted++;
  }

  if (upserted > 0) await batch.commit();

  return { fetched: items.length, upserted };
}
