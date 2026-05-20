"use strict";

/**
 * Agrega contestações de uma ocorrência e marca o relato como `contested`
 * quando o número de usuários distintos atingir um threshold.
 *
 * Trigger: criação de doc em /contestations/{id}.
 *
 * Estratégia anti-abuso: contamos UIDs *distintos*. Um mesmo usuário
 * contestando 100 vezes o mesmo relato gera 100 docs mas conta como 1.
 * O próprio doc da contestação guarda o UID (regra do Firestore exige).
 *
 * Não deletamos contestações nem o relato — apenas marcamos o relato
 * com `contested: true` e gravamos um breakdown. O cliente pode então
 * exibir um indicador visual ("X usuários questionam este relato")
 * sem suprimir a informação.
 *
 * Se contestações forem deletadas no futuro (V2 — moderação reversa),
 * essa função precisa virar onWrite e recalcular do zero.
 */

const admin = require("firebase-admin");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { logger } = require("firebase-functions/v2");

// Threshold de UIDs distintos para marcar o relato como contestado.
// Calibragem inicial conservadora — sobe se virar vetor de abuso, desce
// se o sinal estiver chegando tarde demais pra ser útil.
const CONTESTATION_THRESHOLD = 3;

/**
 * Lógica pura de agregação. Dada uma lista de docs de contestação,
 * devolve o que escrever no doc da ocorrência.
 *
 * @param {Array<{submittedBy?: string, reason?: string}>} contestations
 * @returns {{
 *   contestationCount: number,
 *   contestationDistinctUsers: number,
 *   contestationReasonBreakdown: Object<string, number>,
 *   contested: boolean
 * }}
 */
function aggregate(contestations) {
  const distinctUids = new Set();
  const reasonCounts = {};
  for (const c of contestations) {
    if (c && typeof c.submittedBy === "string" && c.submittedBy.length > 0) {
      distinctUids.add(c.submittedBy);
    }
    if (c && typeof c.reason === "string" && c.reason.length > 0) {
      reasonCounts[c.reason] = (reasonCounts[c.reason] || 0) + 1;
    }
  }
  return {
    contestationCount: contestations.length,
    contestationDistinctUsers: distinctUids.size,
    contestationReasonBreakdown: reasonCounts,
    contested: distinctUids.size >= CONTESTATION_THRESHOLD,
  };
}

exports.onContestationCreated = onDocumentCreated(
  {
    document: "contestations/{contestationId}",
    region: "southamerica-east1",
    memory: "256MiB",
  },
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    const occurrenceId = data.occurrenceId;
    if (!occurrenceId || typeof occurrenceId !== "string") {
      logger.warn("contestation without occurrenceId, skipping", {
        id: event.params.contestationId,
      });
      return;
    }

    const db = admin.firestore();

    const snap = await db
      .collection("contestations")
      .where("occurrenceId", "==", occurrenceId)
      .get();

    const contestations = snap.docs.map((d) => d.data());
    const agg = aggregate(contestations);

    const update = {
      contestationCount: agg.contestationCount,
      contestationDistinctUsers: agg.contestationDistinctUsers,
      contestationReasonBreakdown: agg.contestationReasonBreakdown,
      contestationsLastUpdated:
        admin.firestore.FieldValue.serverTimestamp(),
    };
    if (agg.contested) {
      update.contested = true;
      update.contestedAt = admin.firestore.FieldValue.serverTimestamp();
    }

    await db
      .collection("occurrences")
      .doc(occurrenceId)
      .set(update, { merge: true });

    logger.info("contestation aggregated", {
      occurrenceId,
      distinctUsers: agg.contestationDistinctUsers,
      total: agg.contestationCount,
      contested: agg.contested,
    });
  },
);

exports._internal = { aggregate, CONTESTATION_THRESHOLD };
