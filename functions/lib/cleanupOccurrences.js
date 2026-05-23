"use strict";

/**
 * Cleanup diário de ocorrências e cache de dedup.
 *
 * Sem essa função, Firestore acumula docs indefinidamente. Custo
 * marginal (poucos centavos/mês), mas escala mal sem cleanup.
 *
 * Frequência: 1x/dia às 03:00 BRT (baixo tráfego).
 * Regras:
 *   - occurrences com expiresAt < agora-buffer → DELETE
 *   - news_seen com seenAt < 90 dias → DELETE (cache de dedup pode
 *     reciclar; se a notícia voltar a aparecer em 90+ dias, é coberto
 *     pelo doc-id determinístico de occurrences sem prejuízo)
 *
 * Batch writer pra eficiência (até 500 ops/batch, suporta lotes grandes).
 */

const admin = require("firebase-admin");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { logger } = require("firebase-functions/v2");
const { runWithHealth } = require("./jobHealth");

const OCCURRENCE_BUFFER_HOURS = 24; // mantemos 1 dia após expiresAt
const NEWS_SEEN_TTL_DAYS = 90;

exports.cleanupOccurrences = onSchedule(
  {
    schedule: "0 3 * * *",
    timeZone: "America/Bahia",
    region: "southamerica-east1",
    memory: "256MiB",
    timeoutSeconds: 540,
  },
  async () => runWithHealth("cleanupOccurrences", async () => {
    const db = admin.firestore();
    const now = new Date();

    const occCutoff = new Date(
      now.getTime() - OCCURRENCE_BUFFER_HOURS * 60 * 60 * 1000
    );
    const seenCutoff = new Date(
      now.getTime() - NEWS_SEEN_TTL_DAYS * 24 * 60 * 60 * 1000
    );

    const stats = {
      occurrencesDeleted: 0,
      newsSeenDeleted: 0,
      occurrencesFailed: 0,
      newsSeenFailed: 0,
    };

    // 1. Limpa occurrences expiradas
    const occSnap = await db
      .collection("occurrences")
      .where("expiresAt", "<", admin.firestore.Timestamp.fromDate(occCutoff))
      .get();

    if (!occSnap.empty) {
      stats.occurrencesDeleted = await bulkDelete(db, occSnap.docs, (n) => {
        stats.occurrencesFailed += n;
      });
    }

    // 2. Limpa news_seen antigo
    const seenSnap = await db
      .collection("news_seen")
      .where("seenAt", "<", admin.firestore.Timestamp.fromDate(seenCutoff))
      .get();

    if (!seenSnap.empty) {
      stats.newsSeenDeleted = await bulkDelete(db, seenSnap.docs, (n) => {
        stats.newsSeenFailed += n;
      });
    }

    logger.info("Cleanup concluído", stats);
    return { itemsWritten: stats.occurrencesDeleted + stats.newsSeenDeleted };
  })
);

/**
 * Wrapper sobre bulkWriter pra contabilizar falhas parciais. Sem o
 * `onWriteError`, deleções que falham silenciosamente entram no
 * bulkWriter.close() sem indicação — stats vira mentira. Aqui registramos
 * cada falha e expomos a contagem nas stats finais.
 */
async function bulkDelete(db, docs, onFailure) {
  const writer = db.bulkWriter();
  let failures = 0;
  writer.onWriteError((err) => {
    failures++;
    logger.warn(
      `bulkWriter falhou em ${err.documentRef.path}: ${err.message}`
    );
    // Retorno false interrompe retries do próprio writer. Preferimos
    // não reter um item travado (causaria loop infinito) — log + move on.
    return false;
  });
  for (const doc of docs) {
    writer.delete(doc.ref);
  }
  await writer.close();
  if (failures > 0) onFailure(failures);
  return docs.length - failures;
}
