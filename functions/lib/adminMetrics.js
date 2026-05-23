"use strict";

/**
 * Agrega métricas operacionais do Faro pra um painel admin interno.
 *
 * Roda a cada 30 minutos e escreve um doc único `/admin_metrics/current`
 * com tudo o que o painel precisa exibir. Mantém também um snapshot
 * diário em `/admin_metrics/history/{YYYY-MM-DD}` que sobrescreve ao
 * longo do dia — o último write do dia fica como série temporal.
 *
 * Princípio: ler do server-side pra não obrigar o cliente admin a
 * varrer coleções inteiras. Custom claim `admin` gateia a leitura
 * via Firestore rules.
 *
 * O que entra:
 *   - Usuários (Firebase Auth listUsers): total, anônimos, Google,
 *     criados/ativos nas últimas 24h e 7d.
 *   - Ocorrências (últimos 7d via scan; total all-time via count()):
 *     totais, breakdown por source/state/city, contestadas.
 *   - Contestações: total + ocorrências distintas contestadas.
 *   - Safe arrivals: soma dos "cheguei bem" últimos 7d.
 *
 * Custo: 1 leitura paginada de Auth, ~3 scans Firestore filtrados por
 * data, 2 writes. A cada 30 min = 48 runs/dia → cabe no free tier
 * sem stress.
 */

const admin = require("firebase-admin");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { logger } = require("firebase-functions/v2");
const { runWithHealth } = require("./jobHealth");

const DAY_MS = 24 * 60 * 60 * 1000;
const AUTH_PAGE_SIZE = 1000;

exports.aggregateAdminMetrics = onSchedule(
  {
    schedule: "every 30 minutes",
    timeZone: "America/Bahia",
    region: "southamerica-east1",
    memory: "512MiB",
    timeoutSeconds: 300,
  },
  async () => runWithHealth("aggregateAdminMetrics", async () => {
    const db = admin.firestore();
    const now = new Date();
    const last24h = new Date(now.getTime() - DAY_MS);
    const last7d = new Date(now.getTime() - 7 * DAY_MS);

    const [usersRaw, occurrencesRaw, contestationsRaw, safeArrivalsRaw, occurrencesTotal] =
      await Promise.all([
        listAllUsers(),
        scanCollection(db, "occurrences", "date", last7d),
        scanCollection(db, "contestations", null, null),
        scanCollection(db, "safe_arrivals", null, null),
        db.collection("occurrences").count().get().then((s) => s.data().count),
      ]);

    const payload = computeMetrics({
      users: usersRaw,
      occurrencesLast7d: occurrencesRaw,
      occurrencesTotal,
      contestations: contestationsRaw,
      safeArrivals: safeArrivalsRaw,
      now,
    });

    const sampledAt = admin.firestore.FieldValue.serverTimestamp();
    await db
      .collection("admin_metrics")
      .doc("current")
      .set({ ...payload, sampledAt }, { merge: false });

    const dayId = yyyymmdd(now);
    await db
      .collection("admin_metrics")
      .doc("history")
      .collection("daily")
      .doc(dayId)
      .set({ ...payload, sampledAt }, { merge: false });

    logger.info(
      `adminMetrics: ${payload.users.total} users, ${payload.occurrences.total} occurrences, ${payload.occurrences.last7d} last 7d`,
    );
    return { itemsWritten: 1 };
  }),
);

/**
 * Pagina Auth listUsers até o fim. Limite efetivo do Firebase: sem
 * cap explícito, mas cada página é 1000. Em MVP fechado fica numa
 * página só.
 */
async function listAllUsers() {
  const users = [];
  let pageToken;
  do {
    const page = await admin.auth().listUsers(AUTH_PAGE_SIZE, pageToken);
    users.push(...page.users);
    pageToken = page.pageToken;
  } while (pageToken);
  return users;
}

/**
 * Scan paginado por data ou full collection. Retorna array dos data().
 * Se `sinceField`/`since` forem null, scaneia tudo (usado pra coleções
 * já enxutas como contestations e safe_arrivals).
 */
async function scanCollection(db, collection, sinceField, since) {
  let query = db.collection(collection);
  if (sinceField && since) {
    query = query.where(sinceField, ">=", admin.firestore.Timestamp.fromDate(since));
  }
  const snap = await query.get();
  return snap.docs.map((d) => d.data());
}

/**
 * Lógica pura. Recebe os arrays/contadores brutos e devolve o doc
 * pronto pra gravar (sem timestamps). Testável sem Firebase.
 */
function computeMetrics({
  users,
  occurrencesLast7d,
  occurrencesTotal,
  contestations,
  safeArrivals,
  now,
}) {
  const last24hMs = now.getTime() - DAY_MS;
  const last7dMs = now.getTime() - 7 * DAY_MS;

  // ===== usuários =====
  let anonymous = 0;
  let google = 0;
  let createdLast24h = 0;
  let createdLast7d = 0;
  let activeLast24h = 0;
  let activeLast7d = 0;

  for (const u of users) {
    const providers = u.providerData || [];
    if (providers.length === 0) {
      anonymous++;
    } else if (providers.some((p) => p.providerId === "google.com")) {
      google++;
    }

    const created = parseDate(u.metadata && u.metadata.creationTime);
    const lastSignIn = parseDate(u.metadata && u.metadata.lastSignInTime);

    if (created) {
      const t = created.getTime();
      if (t >= last24hMs) createdLast24h++;
      if (t >= last7dMs) createdLast7d++;
    }
    if (lastSignIn) {
      const t = lastSignIn.getTime();
      if (t >= last24hMs) activeLast24h++;
      if (t >= last7dMs) activeLast7d++;
    }
  }

  // ===== ocorrências =====
  let occLast24h = 0;
  let occContested = 0;
  const bySource = {};
  const byState = {};
  const byCity = {};
  const reasonCount = {};

  for (const o of occurrencesLast7d) {
    const date = toDate(o.date);
    if (date && date.getTime() >= last24hMs) occLast24h++;
    if (o.contested === true) occContested++;

    incr(bySource, o.source || "unknown");
    incr(byState, o.state || "unknown");
    incr(byCity, o.city || "unknown");
    if (o.mainReason) incr(reasonCount, o.mainReason);
  }

  const topReasons = Object.entries(reasonCount)
    .sort((a, b) => b[1] - a[1])
    .slice(0, 5)
    .map(([reason, count]) => ({ reason, count }));

  // ===== contestações =====
  const contestedOccurrenceIds = new Set();
  for (const c of contestations) {
    if (c.occurrenceId) contestedOccurrenceIds.add(c.occurrenceId);
  }

  // ===== safe arrivals =====
  let safeLast7d = 0;
  let safeLast24h = 0;
  for (const sa of safeArrivals) {
    const dayStr = sa.day; // "YYYY-MM-DD"
    const dayMs = dayStr ? Date.parse(dayStr + "T00:00:00Z") : NaN;
    const count = typeof sa.count === "number" ? sa.count : 0;
    if (!Number.isFinite(dayMs)) continue;
    if (dayMs >= last7dMs) safeLast7d += count;
    if (dayMs >= last24hMs) safeLast24h += count;
  }

  return {
    users: {
      total: users.length,
      anonymous,
      google,
      createdLast24h,
      createdLast7d,
      activeLast24h,
      activeLast7d,
    },
    occurrences: {
      total: occurrencesTotal,
      last7d: occurrencesLast7d.length,
      last24h: occLast24h,
      contested: occContested,
      bySource,
      byState,
      byCity,
      topReasons,
    },
    contestations: {
      total: contestations.length,
      occurrencesContested: contestedOccurrenceIds.size,
    },
    safeArrivals: {
      last24h: safeLast24h,
      last7d: safeLast7d,
    },
  };
}

function incr(map, key) {
  map[key] = (map[key] || 0) + 1;
}

function toDate(v) {
  if (!v) return null;
  if (v instanceof Date) return v;
  if (typeof v.toDate === "function") return v.toDate();
  return null;
}

function parseDate(s) {
  if (!s) return null;
  const t = Date.parse(s);
  return Number.isFinite(t) ? new Date(t) : null;
}

function yyyymmdd(d) {
  const y = d.getUTCFullYear();
  const m = String(d.getUTCMonth() + 1).padStart(2, "0");
  const day = String(d.getUTCDate()).padStart(2, "0");
  return `${y}-${m}-${day}`;
}

exports._internal = { computeMetrics };
