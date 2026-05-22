"use strict";

/**
 * Agrega contestações de uma ocorrência e marca o relato como `contested`
 * quando o número de usuários distintos atingir um threshold.
 *
 * Trigger: escrita (create/update/delete) em /contestations/{id}. Recalcula
 * do zero a cada evento — barato porque por ocorrência são poucas dezenas
 * de docs no pior caso, e mantém a moderação reversa simples: se um
 * moderador apagar contestações abusivas, o flag `contested` cai junto.
 *
 * Estratégia anti-abuso: contamos UIDs *distintos*. Um mesmo usuário
 * contestando 100 vezes o mesmo relato gera 100 docs mas conta como 1.
 * O próprio doc da contestação guarda o UID (regra do Firestore exige).
 *
 * Não deletamos o relato — apenas marcamos com `contested: true` e
 * gravamos um breakdown. Se o agregado cair abaixo do threshold (deleção
 * de contestações), `contested` é apagado com `FieldValue.delete()`.
 */

const admin = require("firebase-admin");
const { onDocumentWritten } = require("firebase-functions/v2/firestore");
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

exports.onContestationWritten = onDocumentWritten(
  {
    document: "contestations/{contestationId}",
    region: "southamerica-east1",
    memory: "256MiB",
  },
  async (event) => {
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();

    // Pega occurrenceId do estado vigente. Em delete, after é null e
    // precisamos do before pra saber qual relato reagregar. Em update
    // bem-comportado, before.occurrenceId == after.occurrenceId.
    const occurrenceId = after?.occurrenceId || before?.occurrenceId;
    if (!occurrenceId || typeof occurrenceId !== "string") {
      logger.warn("contestation write without occurrenceId, skipping", {
        id: event.params.contestationId,
      });
      return;
    }

    const db = admin.firestore();
    const occRef = db.collection("occurrences").doc(occurrenceId);

    // Wrap em transação pra evitar race em escritas concorrentes no doc
    // da ocorrência. Quando 2+ contestações chegam quase ao mesmo tempo,
    // dois handlers leem o estado, agregam e escrevem — sem proteção, a
    // última escrita pode refletir um agregado parcialmente desatualizado.
    //
    // Lendo o doc da ocorrência DENTRO da transação, marcamos ele como
    // "dependência": se outro handler commitar antes de nós, Firestore
    // faz retry automático (até 5x). No retry, a query de contestações
    // pega o estado mais fresco.
    const agg = await db.runTransaction(async (tx) => {
      await tx.get(occRef);

      const snap = await db
        .collection("contestations")
        .where("occurrenceId", "==", occurrenceId)
        .get();

      const aggregated = aggregate(snap.docs.map((d) => d.data()));

      const update = {
        contestationCount: aggregated.contestationCount,
        contestationDistinctUsers: aggregated.contestationDistinctUsers,
        contestationReasonBreakdown: aggregated.contestationReasonBreakdown,
        contestationsLastUpdated:
          admin.firestore.FieldValue.serverTimestamp(),
      };
      if (aggregated.contested) {
        update.contested = true;
        update.contestedAt = admin.firestore.FieldValue.serverTimestamp();
      } else {
        // Caiu abaixo do threshold (moderação removeu contestações abusivas
        // ou usuário desfez a sua). Tira o flag pro cliente não exibir
        // "contestado" indevidamente.
        update.contested = admin.firestore.FieldValue.delete();
        update.contestedAt = admin.firestore.FieldValue.delete();
      }

      tx.set(occRef, update, { merge: true });
      return aggregated;
    });

    logger.info("contestation aggregated", {
      occurrenceId,
      distinctUsers: agg.contestationDistinctUsers,
      total: agg.contestationCount,
      contested: agg.contested,
    });
  },
);

exports._internal = { aggregate, CONTESTATION_THRESHOLD };
