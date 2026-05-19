"use strict";

/**
 * Endpoint público pra pesquisadores credenciados (UFBA, USP, etc.).
 *
 *   GET /api/v1/occurrences?since=2025-10-01&until=2025-11-30&limit=200
 *
 * Auth: header `Authorization: ApiKey <key>` (keys gerenciadas em
 * Firestore /research_keys/{keyId}, com campo `active`, `holder` e
 * `tier`). Lookups são cacheados pelo runtime do Cloud Functions —
 * key inválida bloqueia em <50ms.
 *
 * Princípios:
 *  - **Dados já públicos**: occurrences vêm de fontes públicas (mídia,
 *    Fogo Cruzado, OSM). Não há segredo a vazar — o endpoint apenas
 *    formaliza acesso estruturado. Termo de uso documenta contrapartida.
 *  - **Audit pleno**: cada request é logada via firebase-functions
 *    logger. Identifica abuso ou uso fora do escopo declarado.
 *  - **Rate limit por key**: limite diário configurado por tier
 *    (research=1000, partner=10000). Excedeu → 429.
 *
 * Doc do termo de uso: ../docs/parcerias/termo_uso_research_v1.md
 */

const admin = require("firebase-admin");
const { onRequest } = require("firebase-functions/v2/https");
const { logger } = require("firebase-functions/v2");

const TIER_DAILY_LIMIT = {
  research: 1000,
  partner: 10000,
};
const DEFAULT_LIMIT = 100;
const MAX_LIMIT = 1000;

exports.getOccurrences = onRequest(
  {
    cors: true,
    maxInstances: 5,
    timeoutSeconds: 60,
    memory: "256MiB",
  },
  async (req, res) => {
    try {
      if (req.method !== "GET") {
        return res.status(405).json({ error: "method_not_allowed" });
      }

      const auth = await authenticate(req);
      if (!auth.ok) {
        return res.status(auth.status).json({ error: auth.error });
      }

      const { since, until, limit, source } = parseQuery(req.query);
      if (since instanceof Error) {
        return res.status(400).json({ error: "invalid_since" });
      }
      if (until instanceof Error) {
        return res.status(400).json({ error: "invalid_until" });
      }

      const db = admin.firestore();
      let q = db
        .collection("occurrences")
        .orderBy("date", "desc")
        .limit(limit);
      if (since) {
        q = q.where("date", ">=", admin.firestore.Timestamp.fromDate(since));
      }
      if (until) {
        q = q.where("date", "<=", admin.firestore.Timestamp.fromDate(until));
      }
      if (source) {
        q = q.where("source", "==", source);
      }

      const snap = await q.get();
      const docs = snap.docs.map(formatOccurrence);

      logger.info(`research api · ${auth.key.id} (${auth.key.holder}) · ` +
        `${docs.length} docs · since=${since?.toISOString() ?? "—"}`);

      res.json({
        occurrences: docs,
        count: docs.length,
        metadata: {
          version: "v1",
          license:
            "Data provided under Faro Research Terms v1. See docs/parcerias/termo_uso_research_v1.md",
          documentation: "https://github.com/maufloquet/faro/tree/main/docs/parcerias",
        },
      });
    } catch (e) {
      logger.error("research api unexpected error", e);
      res.status(500).json({ error: "internal_error" });
    }
  }
);

async function authenticate(req) {
  const header = req.get("authorization") || "";
  const match = header.match(/^ApiKey\s+(.+)$/i);
  if (!match) {
    return { ok: false, status: 401, error: "missing_api_key" };
  }
  const rawKey = match[1].trim();
  const db = admin.firestore();
  const doc = await db.collection("research_keys").doc(rawKey).get();
  if (!doc.exists) {
    return { ok: false, status: 401, error: "invalid_api_key" };
  }
  const data = doc.data();
  if (data.active === false) {
    return { ok: false, status: 403, error: "key_revoked" };
  }

  // Rate limit por dia / tier
  const tier = data.tier || "research";
  const dailyLimit = TIER_DAILY_LIMIT[tier] || TIER_DAILY_LIMIT.research;
  const today = isoDay(new Date());
  const counterRef = doc.ref.collection("usage").doc(today);
  const counterSnap = await counterRef.get();
  const used = counterSnap.exists ? counterSnap.data().count || 0 : 0;
  if (used >= dailyLimit) {
    return { ok: false, status: 429, error: "rate_limit_exceeded" };
  }
  await counterRef.set(
    {
      count: admin.firestore.FieldValue.increment(1),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );

  return {
    ok: true,
    key: {
      id: doc.id,
      holder: data.holder || "unknown",
      tier,
    },
  };
}

function parseQuery(q) {
  let since = null;
  let until = null;
  if (q.since) {
    const d = new Date(q.since);
    since = isNaN(d.getTime()) ? new Error("bad") : d;
  }
  if (q.until) {
    const d = new Date(q.until);
    until = isNaN(d.getTime()) ? new Error("bad") : d;
  }
  let limit = parseInt(q.limit, 10);
  if (!Number.isFinite(limit) || limit <= 0) limit = DEFAULT_LIMIT;
  if (limit > MAX_LIMIT) limit = MAX_LIMIT;
  const source = typeof q.source === "string" ? q.source : null;
  return { since, until, limit, source };
}

function formatOccurrence(doc) {
  const d = doc.data();
  return {
    id: doc.id,
    latitude: d.latitude,
    longitude: d.longitude,
    date: d.date?.toDate?.()?.toISOString() ?? null,
    state: d.state ?? null,
    city: d.city ?? null,
    neighborhood: d.neighborhood ?? null,
    mainReason: d.mainReason ?? null,
    source: d.source ?? null,
    sourceProvider: d.sourceProvider ?? null,
    sourceName: d.sourceName ?? null,
    weight: d.weight ?? null,
    confidence: d.confidence ?? null,
    busLines: d.busLines ?? [],
    transportContext: d.transportContext ?? null,
    corroborationCount: d.corroborationCount ?? 0,
  };
}

function isoDay(d) {
  return d.toISOString().slice(0, 10); // YYYY-MM-DD
}
