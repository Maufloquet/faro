"use strict";

/**
 * Resumo proativo diário — Frente 4 do plano de personalização.
 *
 * Diferente do `proximityAlert`, que é reativo (notifica quando uma
 * ocorrência cria nos arredores), este job é proativo: roda toda manhã,
 * varre os usuários que pediram resumo (`notifications.dailyDigest =
 * true` no perfil) e manda um push personalizado com o que rolou nas
 * últimas 24h no bairro principal deles (ou favoritos).
 *
 * Princípio editorial mantido: o texto NUNCA usa palavras alarmistas.
 * O resumo é informativo ("Esta noite, 3 relatos no seu bairro. Acima
 * da média habitual.") e silencioso quando não há nada a contar.
 *
 * Roda 7h BRT. Estado:
 *   - Sem usuários: não faz nada
 *   - Sem ocorrência no bairro do user: pula esse user (silêncio honesto)
 *   - User sem mainNeighborhood nem favoritos: pula
 *   - User com `dailyDigest = false`: pula
 *
 * Push via FCM message per-uid (token guardado em /users/{uid}/fcmTokens
 * — TODO confirmar se já guardamos isso; senão precisa adicionar).
 */

const admin = require("firebase-admin");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { logger } = require("firebase-functions/v2");

const { runWithHealth } = require("./jobHealth");

const DAY_MS = 24 * 60 * 60 * 1000;
const MIN_RELATOS_PRA_NOTIFICAR = 1;

exports.dailyDigest = onSchedule(
  {
    schedule: "every day 07:00",
    timeZone: "America/Bahia",
    region: "southamerica-east1",
    memory: "512MiB",
    timeoutSeconds: 540,
  },
  async () => runWithHealth("dailyDigest", async () => {
    const db = admin.firestore();
    const since = new Date(Date.now() - DAY_MS);

    // 1. Lista usuários com digest ativo + bairro principal ou favoritos.
    //    Não filtramos por `notifications.dailyDigest == true` na query
    //    (campo aninhado, exige índice composto) — filtramos in-memory
    //    porque o universo é pequeno na fase de beta. Quando passar de
    //    ~5k usuários, migrar pra collection-group ou flag top-level.
    const usersSnap = await db.collection("users").get();

    let sent = 0;
    let skipped = 0;

    for (const userDoc of usersSnap.docs) {
      const user = userDoc.data();
      const prefs = user.notifications || {};
      if (prefs.dailyDigest === false) {
        skipped++;
        continue;
      }

      const targetNeighborhoods = await collectTargetNeighborhoods(db, userDoc);
      if (targetNeighborhoods.length === 0) {
        skipped++;
        continue;
      }

      const summary = await summarizeForUser(db, since, targetNeighborhoods);
      if (summary.totalCount < MIN_RELATOS_PRA_NOTIFICAR) {
        skipped++;
        continue;
      }

      const token = await pickFcmToken(db, userDoc.id);
      if (!token) {
        skipped++;
        continue;
      }

      const message = buildDigestMessage(token, summary, user.displayName);
      try {
        await admin.messaging().send(message);
        sent++;
      } catch (e) {
        logger.warn(`digest send falhou pra uid=${userDoc.id}: ${e.message || e}`);
        // FCM "registration-token-not-registered" = token velho.
        // Limpa silenciosamente pra não tentar de novo amanhã.
        if (e.code === "messaging/registration-token-not-registered") {
          await db
            .collection("users")
            .doc(userDoc.id)
            .collection("fcmTokens")
            .doc(token)
            .delete()
            .catch(() => {});
        }
      }
    }

    logger.info(`dailyDigest: enviados=${sent} pulados=${skipped}`);
    return { itemsWritten: sent };
  }),
);

/**
 * Quais bairros importam pra esse usuário? Prioridade:
 *   1. `mainNeighborhood` no perfil — mais explícito
 *   2. Favoritos do usuário (subcoleção)
 *
 * Retorna lista de nomes normalizados (acento-insensitive, lowercase)
 * pra casar com `occurrence.neighborhood` independente de variação de
 * grafia.
 */
async function collectTargetNeighborhoods(db, userDoc) {
  const data = userDoc.data();
  const out = new Set();
  if (typeof data.mainNeighborhood === "string" && data.mainNeighborhood.trim()) {
    out.add(normalize(data.mainNeighborhood));
  }
  try {
    const favs = await db
      .collection("users")
      .doc(userDoc.id)
      .collection("favorites")
      .get();
    for (const f of favs.docs) {
      const name = f.data().name;
      if (typeof name === "string" && name.trim()) {
        out.add(normalize(name));
      }
    }
  } catch (_) {}
  return Array.from(out);
}

/**
 * Agrega ocorrências dos últimos 24h cujo bairro casa com algum dos
 * alvos do usuário. Retorna count + breakdown por motivo.
 */
async function summarizeForUser(db, since, targetNeighborhoods) {
  const snap = await db
    .collection("occurrences")
    .where("date", ">=", admin.firestore.Timestamp.fromDate(since))
    .get();

  const targets = new Set(targetNeighborhoods);
  const reasons = new Map();
  const neighborhoodsHit = new Set();
  let totalCount = 0;

  for (const doc of snap.docs) {
    const o = doc.data();
    const n = normalize(o.neighborhood);
    if (!n || !targets.has(n)) continue;
    totalCount++;
    neighborhoodsHit.add(o.neighborhood);
    if (o.mainReason) {
      reasons.set(o.mainReason, (reasons.get(o.mainReason) || 0) + 1);
    }
  }

  // Top reason: o motivo mais frequente.
  let topReason = null;
  let topCount = 0;
  for (const [r, c] of reasons.entries()) {
    if (c > topCount) {
      topReason = r;
      topCount = c;
    }
  }

  return {
    totalCount,
    topReason,
    topReasonCount: topCount,
    neighborhoods: Array.from(neighborhoodsHit),
  };
}

/**
 * Texto editorial. Tom: informativo, nunca alarmista. Princípio do Faro
 * — sem PERIGO/CUIDADO/EVITE/URGENTE. Variação no greeting + corpo.
 *
 * Pura. Testável.
 */
function buildDigestText(summary, displayName) {
  const greeting = displayName && displayName.trim().length > 0
    ? `Bom dia, ${displayName.trim()}.`
    : "Bom dia.";
  const where = summary.neighborhoods.length === 1
    ? summary.neighborhoods[0]
    : `seus bairros`;
  const countLabel = summary.totalCount === 1
    ? "1 relato"
    : `${summary.totalCount} relatos`;
  const reasonClause =
    summary.topReason && summary.topReasonCount >= Math.ceil(summary.totalCount * 0.5)
      ? ` Principal motivo: ${summary.topReason.toLowerCase()}.`
      : "";
  return `${greeting} Nas últimas 24h, ${countLabel} em ${where}.${reasonClause}`;
}

function buildDigestMessage(token, summary, displayName) {
  const body = buildDigestText(summary, displayName);
  return {
    token,
    notification: {
      title: "Resumo do Faro",
      body,
    },
    data: {
      type: "daily_digest",
      count: String(summary.totalCount),
    },
    android: {
      notification: {
        channelId: "faro_digest",
        priority: "default",
      },
    },
    apns: {
      payload: {
        aps: {
          sound: "default",
          contentAvailable: 1,
        },
      },
    },
  };
}

/**
 * Pega o token FCM mais recente do usuário. Convenção:
 * /users/{uid}/fcmTokens/{token} com campo `updatedAt`.
 *
 * Se o usuário usa o app em vários devices, mandamos só pro mais
 * recente — evita push duplicado. (V2: notification topic agrupado.)
 */
async function pickFcmToken(db, uid) {
  try {
    const snap = await db
      .collection("users")
      .doc(uid)
      .collection("fcmTokens")
      .orderBy("updatedAt", "desc")
      .limit(1)
      .get();
    if (snap.empty) return null;
    return snap.docs[0].id;
  } catch (_) {
    return null;
  }
}

function normalize(s) {
  if (!s) return "";
  return String(s)
    .toLowerCase()
    .normalize("NFD")
    .replace(/[̀-ͯ]/g, "")
    .trim();
}

exports._internal = { buildDigestText, normalize, summarizeForUser };
