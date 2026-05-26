"use strict";

/**
 * Reputação invisível do autor de relatos (Camada 4, bloco 3).
 *
 * Nunca é mostrada ao usuário. Serve só pra calibrar o peso editorial dos
 * relatos que ele abre: quem tem histórico de relatos confirmados pela
 * vizinhança entra com peso um pouco maior; quem acumula rejeições, menor.
 * Isso recompensa relatores confiáveis sem gamificação visível (que viraria
 * incentivo a inflar relato).
 *
 * Vive em /user_reputation/{uid} (rules: só Cloud Function lê/escreve).
 */

const admin = require("firebase-admin");

const BASE_WEIGHT = 0.4;
const MIN_WEIGHT = 0.3;
const MAX_WEIGHT = 0.6;
// Quanto cada ponto líquido de reputação move o peso. 10 pontos satura.
const WEIGHT_PER_POINT = 0.02;

/**
 * Converte o score de reputação no peso editorial da ocorrência promovida.
 * Pura. Score 0 → peso base; positivo sobe até o teto, negativo desce até
 * o piso. Tolera score ausente/não-numérico (trata como 0).
 */
function reputationToWeight(score) {
  const s = typeof score === "number" && Number.isFinite(score) ? score : 0;
  const w = BASE_WEIGHT + WEIGHT_PER_POINT * s;
  return Math.max(MIN_WEIGHT, Math.min(MAX_WEIGHT, w));
}

/** Lê o score de reputação do uid (0 se não existe). */
async function getReputationScore(db, uid) {
  if (!uid) return 0;
  const snap = await db.collection("user_reputation").doc(uid).get();
  if (!snap.exists) return 0;
  const s = snap.data().score;
  return typeof s === "number" && Number.isFinite(s) ? s : 0;
}

/**
 * Aplica um delta na reputação do uid. `confirmedDelta`/`rejectedDelta`
 * incrementam os contadores; `scoreDelta` move o score líquido.
 * Idempotência não é garantida — chamar só na TRANSIÇÃO de status.
 */
async function applyReputationDelta(db, uid, { scoreDelta = 0, confirmedDelta = 0, rejectedDelta = 0 }) {
  if (!uid) return;
  const ref = db.collection("user_reputation").doc(uid);
  const inc = admin.firestore.FieldValue.increment;
  await ref.set(
    {
      score: inc(scoreDelta),
      confirmed: inc(confirmedDelta),
      rejected: inc(rejectedDelta),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
}

module.exports = {
  reputationToWeight,
  getReputationScore,
  applyReputationDelta,
};
module.exports._internal = { reputationToWeight, BASE_WEIGHT, MIN_WEIGHT, MAX_WEIGHT };
