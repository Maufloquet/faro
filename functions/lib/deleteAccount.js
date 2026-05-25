"use strict";

/**
 * Apaga a conta do usuário e tudo o que está vinculado a ela — a parte
 * que o cliente não consegue fazer sozinho.
 *
 * Por que existe: o cliente apaga o que as rules permitem (doc /users/{uid}
 * e a subcoleção /favorites), mas dois pontos ficam fora do alcance dele:
 *
 *   1. Contestações em /contestations onde submittedBy == uid. A rule
 *      `allow delete: if false` bloqueia o cliente de propósito (moderação
 *      reversa é server-side). Só o admin SDK apaga.
 *   2. A própria conta no Firebase Auth. O cliente pode chamar user.delete(),
 *      mas isso falha com `requires-recent-login` se o login for antigo —
 *      o admin SDK não tem essa restrição.
 *
 * Também varremos a subcoleção /fcmTokens (tokens de push), que o cliente
 * não limpava no fluxo antigo.
 *
 * Não toca em /safe_arrivals: é um agregado anônimo por célula+dia, sem uid
 * — não há o que reidentificar nem apagar lá.
 *
 * Ordem deliberada: dados primeiro, conta Auth por último. Se a deleção de
 * dados falhar no meio, a conta continua existindo e o usuário pode tentar
 * de novo. O contrário deixaria dados órfãos sem dono que os apague.
 *
 * Quando uma contestação some, o trigger `onContestationWritten` reagrega a
 * ocorrência sozinho e remove o flag `contested` se cair abaixo do
 * threshold — não precisamos mexer nas ocorrências aqui.
 */

const admin = require("firebase-admin");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { logger } = require("firebase-functions/v2");

// Limite do batch do Firestore. Contestações de um usuário em geral são
// poucas, mas um usuário antigo pode ter dezenas — partimos em lotes pra
// nunca estourar.
const BATCH_LIMIT = 500;

exports.deleteAccountCascade = onCall(
  {
    region: "southamerica-east1",
    memory: "256MiB",
  },
  async (request) => {
    if (!request.auth || !request.auth.uid) {
      throw new HttpsError(
        "unauthenticated",
        "Precisa estar autenticado pra apagar a própria conta.",
      );
    }
    const uid = request.auth.uid;
    const db = admin.firestore();

    let contestationsDeleted = 0;
    try {
      contestationsDeleted = await deleteContestationsBy(db, uid);
    } catch (e) {
      logger.error(`delete cascade: apagar contestações falhou uid=${uid}`, e);
      throw new HttpsError(
        "internal",
        "Não foi possível apagar suas contestações. Tente de novo.",
      );
    }

    // Apaga o doc do usuário e tudo abaixo dele (favorites, fcmTokens).
    // recursiveDelete cuida das subcoleções — o cliente só conseguia o
    // doc raiz e os favoritos.
    try {
      await db.recursiveDelete(db.collection("users").doc(uid));
    } catch (e) {
      logger.error(`delete cascade: apagar /users/${uid} falhou`, e);
      throw new HttpsError(
        "internal",
        "Não foi possível apagar seu perfil. Tente de novo.",
      );
    }

    // Conta Auth por último. Idempotente: se já não existe, seguimos.
    try {
      await admin.auth().deleteUser(uid);
    } catch (e) {
      if (e && e.code === "auth/user-not-found") {
        logger.info(`delete cascade: conta Auth uid=${uid} já não existia`);
      } else {
        logger.error(`delete cascade: apagar conta Auth uid=${uid} falhou`, e);
        throw new HttpsError(
          "internal",
          "Seus dados foram apagados, mas a conta de login não. Contate o suporte.",
        );
      }
    }

    logger.info(
      `delete cascade ok uid=${uid} contestacoes=${contestationsDeleted}`,
    );
    return {
      ok: true,
      contestationsDeleted,
    };
  },
);

/**
 * Apaga todas as contestações de autoria do uid, em lotes de BATCH_LIMIT.
 * Retorna quantas foram apagadas.
 */
async function deleteContestationsBy(db, uid) {
  const snap = await db
    .collection("contestations")
    .where("submittedBy", "==", uid)
    .get();

  if (snap.empty) return 0;

  let deleted = 0;
  for (const group of chunk(snap.docs, BATCH_LIMIT)) {
    const batch = db.batch();
    for (const doc of group) {
      batch.delete(doc.ref);
    }
    await batch.commit();
    deleted += group.length;
  }
  return deleted;
}

/**
 * Parte um array em pedaços de no máximo `size`. Puro — base do batching.
 */
function chunk(arr, size) {
  if (size <= 0) throw new RangeError("size precisa ser > 0");
  const out = [];
  for (let i = 0; i < arr.length; i += size) {
    out.push(arr.slice(i, i + size));
  }
  return out;
}

exports._internal = { chunk, BATCH_LIMIT };
