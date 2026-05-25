"use strict";

/**
 * Validação coletiva dos relatos de usuário (Camada 4, bloco 2).
 *
 * Trigger: escrita em /reports/{reportId}/votes/{voterUid}. Reconta do zero
 * a cada voto — por relato são poucos votos, e recalcular mantém a moderação
 * reversa simples (se um voto for removido por moderação, a contagem cai).
 *
 * Regras de contagem:
 *   - Conta UIDs distintos (1 voto por usuário, garantido pelo id do doc).
 *   - IGNORA o voto do próprio autor — não vale auto-confirmar.
 *   - confirm >= CONFIRM_THRESHOLD e confirm >= contest → confirmado:
 *     promove pra /occurrences com source='user_report' (entra no mapa e
 *     nas agregações como relato validado pela vizinhança).
 *   - contest >= CONTEST_THRESHOLD e contest > confirm → rejeitado: some do
 *     mapa; se já tinha sido promovido, a ocorrência promovida é apagada.
 *
 * Princípio editorial: relato de usuário só vira ocorrência depois que
 * gente perto confirma. Antes disso é boato e fica fora das estatísticas.
 */

const admin = require("firebase-admin");
const { onDocumentWritten } = require("firebase-functions/v2/firestore");
const { logger } = require("firebase-functions/v2");
const ngeohash = require("ngeohash");

const { mapType } = require("./newsIngest")._internal;

// Limiares calibrados pra base pequena do beta. Sobem quando houver volume.
const CONFIRM_THRESHOLD = 2;
const CONTEST_THRESHOLD = 2;

// TTL da ocorrência promovida a partir de relato confirmado. Mais curto
// que o das fontes oficiais (30d) — relato de usuário envelhece rápido.
const PROMOTED_TTL_DAYS = 7;
// Peso editorial de um relato confirmado pela vizinhança. Abaixo das fontes
// oficiais; o bloco 3 (reputação) pode ajustar pra cima/baixo.
const PROMOTED_WEIGHT = 0.4;

/**
 * Lógica pura. Dada a lista de votos e o autor, devolve contagens e status.
 *
 * @param {Array<{id: string, vote: string}>} votes  id = uid do votante
 * @param {string} authorUid
 * @param {{confirmThreshold: number, contestThreshold: number}} opts
 */
function aggregateVotes(votes, authorUid, opts = {}) {
  const confirmThreshold = opts.confirmThreshold ?? CONFIRM_THRESHOLD;
  const contestThreshold = opts.contestThreshold ?? CONTEST_THRESHOLD;

  const confirmers = new Set();
  const contesters = new Set();
  for (const v of votes) {
    if (!v || typeof v.id !== "string" || v.id === authorUid) continue;
    if (v.vote === "confirm") confirmers.add(v.id);
    else if (v.vote === "contest") contesters.add(v.id);
  }
  const confirmCount = confirmers.size;
  const contestCount = contesters.size;

  let status = "pending";
  if (confirmCount >= confirmThreshold && confirmCount >= contestCount) {
    status = "confirmed";
  } else if (contestCount >= contestThreshold && contestCount > confirmCount) {
    status = "rejected";
  }
  return { confirmCount, contestCount, status };
}

/**
 * Monta o doc de /occurrences a partir de um relato confirmado. Puro.
 */
function buildPromotedOccurrence(report, reportId, now = new Date()) {
  const createdAt =
    report.createdAt && report.createdAt.toDate
      ? report.createdAt.toDate()
      : now;
  const expiresAt = new Date(
    createdAt.getTime() + PROMOTED_TTL_DAYS * 24 * 60 * 60 * 1000,
  );
  return {
    latitude: report.lat,
    longitude: report.lng,
    geohash: ngeohash.encode(report.lat, report.lng, 8),
    date: admin.firestore.Timestamp.fromDate(createdAt),
    expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
    // MVP é Salvador/RMS; o recorte regional do cliente garante BA.
    state: "Bahia",
    city: report.city || null,
    neighborhood: report.neighborhood || null,
    geocodeMethod: "user_gps",
    mainReason: mapType(report.type),
    source: "user_report",
    weight: PROMOTED_WEIGHT,
    reportId,
    confirmCount: report.confirmCount || 0,
    ingestedAt: admin.firestore.FieldValue.serverTimestamp(),
  };
}

exports.onReportVoteWritten = onDocumentWritten(
  {
    document: "reports/{reportId}/votes/{voterUid}",
    region: "southamerica-east1",
    memory: "256MiB",
  },
  async (event) => {
    const reportId = event.params.reportId;
    const db = admin.firestore();
    const reportRef = db.collection("reports").doc(reportId);

    const reportSnap = await reportRef.get();
    if (!reportSnap.exists) {
      logger.warn(`voto em relato inexistente: ${reportId}`);
      return;
    }
    const report = reportSnap.data();

    const votesSnap = await reportRef.collection("votes").get();
    const votes = votesSnap.docs.map((d) => ({ id: d.id, vote: d.data().vote }));
    const agg = aggregateVotes(votes, report.createdBy);

    const occRef = db.collection("occurrences").doc(`user-${reportId}`);

    await reportRef.update({
      confirmCount: agg.confirmCount,
      contestCount: agg.contestCount,
      status: agg.status,
      votesUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    if (agg.status === "confirmed") {
      // Promove (idempotente — docId determinístico, merge).
      const occ = buildPromotedOccurrence(
        { ...report, confirmCount: agg.confirmCount },
        reportId,
      );
      await occRef.set(occ, { merge: true });
      logger.info(`relato ${reportId} confirmado e promovido (confirm=${agg.confirmCount})`);
    } else if (agg.status === "rejected") {
      // Se tinha sido promovido antes, tira do mapa.
      await occRef.delete().catch(() => {});
      logger.info(`relato ${reportId} rejeitado (contest=${agg.contestCount})`);
    }
  },
);

exports._internal = {
  aggregateVotes,
  buildPromotedOccurrence,
  CONFIRM_THRESHOLD,
  CONTEST_THRESHOLD,
  PROMOTED_TTL_DAYS,
  PROMOTED_WEIGHT,
};
