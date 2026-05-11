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
  async () => {
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
    };

    // 1. Limpa occurrences expiradas
    const occSnap = await db
      .collection("occurrences")
      .where("expiresAt", "<", admin.firestore.Timestamp.fromDate(occCutoff))
      .get();

    if (!occSnap.empty) {
      const writer = db.bulkWriter();
      for (const doc of occSnap.docs) {
        writer.delete(doc.ref);
      }
      await writer.close();
      stats.occurrencesDeleted = occSnap.size;
    }

    // 2. Limpa news_seen antigo
    const seenSnap = await db
      .collection("news_seen")
      .where("seenAt", "<", admin.firestore.Timestamp.fromDate(seenCutoff))
      .get();

    if (!seenSnap.empty) {
      const writer = db.bulkWriter();
      for (const doc of seenSnap.docs) {
        writer.delete(doc.ref);
      }
      await writer.close();
      stats.newsSeenDeleted = seenSnap.size;
    }

    logger.info("Cleanup concluído", stats);
  }
);
