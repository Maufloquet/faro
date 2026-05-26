"use strict";

/**
 * Expira relatos de usuário não-confirmados (Camada 4, bloco 3).
 *
 * Relato pendente que ninguém confirmou dentro da janela (createdAt + 4h,
 * gravada em expiresAt pelo cliente) vira status='expired' e some do mapa.
 * Princípio editorial: boato não confirmado não fica pendurado — se a
 * vizinhança não corroborou em poucas horas, perde validade.
 *
 * Relato confirmado já foi promovido a /occurrences (com TTL próprio,
 * limpo pelo cleanupOccurrences) — aqui só mexemos em pendentes.
 *
 * Roda a cada 15 min. Query por expiresAt <= agora (índice de campo único,
 * sem composto) e filtra status='pending' no código.
 */

const admin = require("firebase-admin");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { logger } = require("firebase-functions/v2");

const { runWithHealth } = require("./jobHealth");

const SCAN_LIMIT = 500;
const BATCH_LIMIT = 400;

/**
 * Puro: um relato deve expirar agora? Só pendentes com expiresAt no passado.
 * Tolera Timestamp do Firestore (toMillis) ou Date.
 */
function isExpired(report, nowMs) {
  if (!report || report.status !== "pending") return false;
  const exp = report.expiresAt;
  let ms = null;
  if (exp && typeof exp.toMillis === "function") ms = exp.toMillis();
  else if (exp instanceof Date) ms = exp.getTime();
  if (ms == null) return false;
  return ms <= nowMs;
}

function chunk(arr, size) {
  const out = [];
  for (let i = 0; i < arr.length; i += size) out.push(arr.slice(i, i + size));
  return out;
}

exports.expireReports = onSchedule(
  {
    schedule: "every 15 minutes",
    timeZone: "America/Bahia",
    region: "southamerica-east1",
    memory: "256MiB",
  },
  async () => runWithHealth("expireReports", async () => {
    const db = admin.firestore();
    const nowMs = Date.now();
    const nowTs = admin.firestore.Timestamp.fromMillis(nowMs);

    const snap = await db
      .collection("reports")
      .where("expiresAt", "<=", nowTs)
      .limit(SCAN_LIMIT)
      .get();

    const toExpire = snap.docs.filter((d) => isExpired(d.data(), nowMs));
    let expired = 0;
    for (const group of chunk(toExpire, BATCH_LIMIT)) {
      const batch = db.batch();
      for (const d of group) {
        batch.update(d.ref, {
          status: "expired",
          expiredAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
      expired += group.length;
    }

    logger.info(`expireReports: ${expired} relatos expirados`);
    return { itemsWritten: expired };
  }),
);

exports._internal = { isExpired, chunk };
