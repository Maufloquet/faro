"use strict";

/**
 * Exporta tudo o que o Faro guarda sobre o usuário — a versão completa,
 * que o cliente sozinho não consegue montar.
 *
 * Por que existe: o app já lê o que as rules permitem (perfil + favoritos),
 * mas as contestações ficam de fora porque a rule `allow read: if false`
 * barra qualquer leitura pelo cliente (são visíveis só via admin). Pra
 * cumprir o direito de acesso da LGPD por inteiro, esta Cloud Function roda
 * com admin SDK e devolve também as contestações de autoria do usuário.
 *
 * Espelha a `deleteAccountCascade`: as duas cobrem exatamente o que o
 * cliente não alcança. O que NÃO entra aqui:
 *   - /safe_arrivals — agregado anônimo por célula+dia, sem uid; não há
 *     dado pessoal a devolver.
 *   - identificadores opacos do Firebase que não são "dados do usuário".
 *
 * Retorna um objeto JSON-serializável (Timestamps já viram ISO 8601). O
 * cliente só formata e salva/compartilha.
 */

const admin = require("firebase-admin");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { logger } = require("firebase-functions/v2");

exports.exportUserData = onCall(
  {
    region: "southamerica-east1",
    memory: "256MiB",
  },
  async (request) => {
    if (!request.auth || !request.auth.uid) {
      throw new HttpsError(
        "unauthenticated",
        "Precisa estar autenticado pra exportar seus dados.",
      );
    }
    const uid = request.auth.uid;
    const db = admin.firestore();

    try {
      const userRef = db.collection("users").doc(uid);
      const [userDoc, favSnap, tokensSnap, contestSnap] = await Promise.all([
        userRef.get(),
        userRef.collection("favorites").get(),
        userRef.collection("fcmTokens").get(),
        db.collection("contestations").where("submittedBy", "==", uid).get(),
      ]);

      const bundle = buildExportBundle({
        uid,
        token: request.auth.token || {},
        profile: userDoc.exists ? userDoc.data() : null,
        favorites: favSnap.docs.map((d) => ({ id: d.id, ...d.data() })),
        fcmTokens: tokensSnap.docs.map((d) => ({ id: d.id, ...d.data() })),
        contestations: contestSnap.docs.map((d) => ({ id: d.id, ...d.data() })),
        exportedAt: new Date(),
      });

      logger.info(
        `export ok uid=${uid} favoritos=${bundle.favoritos.length} ` +
          `contestacoes=${bundle.contestacoes.length}`,
      );
      return bundle;
    } catch (e) {
      logger.error(`export falhou uid=${uid}`, e);
      throw new HttpsError(
        "internal",
        "Não foi possível montar seu pacote de dados. Tente de novo.",
      );
    }
  },
);

/**
 * Monta o objeto final de exportação a partir das partes já lidas. Puro —
 * recebe dados crus do Firestore (com Timestamps) e devolve algo pronto pra
 * JSON.stringify, com datas em ISO 8601 e rótulos em português.
 *
 * @param {{
 *   uid: string,
 *   token: Object,
 *   profile: Object|null,
 *   favorites: Array<Object>,
 *   fcmTokens: Array<Object>,
 *   contestations: Array<Object>,
 *   exportedAt: Date,
 * }} parts
 */
function buildExportBundle(parts) {
  const token = parts.token || {};
  return {
    exportadoEm: toIso(parts.exportedAt),
    uid: parts.uid,
    email: token.email || null,
    displayName: token.name || null,
    anonimo: token.firebase
      ? token.firebase.sign_in_provider === "anonymous"
      : null,
    perfil: serialize(parts.profile) || {},
    favoritos: serialize(parts.favorites) || [],
    tokensDePush: serialize(parts.fcmTokens) || [],
    contestacoes: serialize(parts.contestations) || [],
  };
}

/**
 * Converte recursivamente Timestamps do Firestore em strings ISO 8601 e
 * deixa o resto intacto. Cobre os tipos que aparecem nos nossos docs:
 * Timestamp, Date, objetos aninhados, arrays e primitivos.
 */
function serialize(value) {
  if (value === null || value === undefined) return value;

  // Timestamp do admin SDK: tem toDate(). Date nativo idem.
  if (typeof value.toDate === "function") {
    return value.toDate().toISOString();
  }
  if (value instanceof Date) {
    return value.toISOString();
  }
  // Timestamp já serializado (vindo de um mock/JSON): {_seconds, _nanoseconds}.
  if (
    typeof value === "object" &&
    typeof value._seconds === "number" &&
    typeof value._nanoseconds === "number"
  ) {
    return new Date(value._seconds * 1000).toISOString();
  }
  if (Array.isArray(value)) {
    return value.map(serialize);
  }
  if (typeof value === "object") {
    const out = {};
    for (const [k, v] of Object.entries(value)) {
      out[k] = serialize(v);
    }
    return out;
  }
  return value;
}

function toIso(d) {
  return d instanceof Date ? d.toISOString() : new Date().toISOString();
}

exports._internal = { buildExportBundle, serialize };
