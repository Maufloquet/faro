"use strict";

/**
 * Camadas de infraestrutura urbana (delegacias, hospitais, postes de
 * iluminação, comércio 24h) via OpenStreetMap Overpass API. Cada uma
 * vira single doc em /osm/{kind}.
 *
 * Dois pontos de entrada:
 *  - `fetchOsmInfra` (HTTP, admin): atualização manual one-shot, suporta
 *    ?kinds=police,hospitals pra refresh seletivo.
 *  - `syncOsmInfra` (scheduler, semanal): mantém o snapshot fresco sem
 *    intervenção. Esses dados mudam pouco — semanal cobre com folga.
 *
 * Por que essas camadas: peso editorial alto — Faro mostra infraestrutura
 * existente como contexto, não como veredito. "Tem delegacia/hospital/poste
 * aqui" é informação acionável; "área perigosa" é julgamento que o app evita.
 * Ver docs/roadmap_features.md §"Camada 6 — OSM Overpass".
 *
 * Custo: Overpass é grátis, sem auth. Limite ~10k queries/dia compartilhado.
 * Tick semanal = 4 queries/run × 1 run/semana, folga absoluta.
 *
 * Idempotente: roda 2x, sobrescreve com snapshot fresco.
 */

const admin = require("firebase-admin");
const { onRequest } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { logger } = require("firebase-functions/v2");

const OVERPASS_URL = "https://overpass-api.de/api/interpreter";

// Bbox da RMS — south, west, north, east. Mesma margem do osmFetch (RMS).
const RMS_BBOX = "-13.05,-38.65,-12.65,-38.20";

// Bbox menor (só Salvador urbano) pra postes — street_lamp pode ter milhares
// de nós e a RMS inteira estoura o limite editorial de "contexto, não ruído".
const SALVADOR_URBAN_BBOX = "-13.02,-38.55,-12.85,-38.35";

const QUERIES = {
  police: {
    bbox: RMS_BBOX,
    query: (bbox) => `
[out:json][timeout:60];
(
  node["amenity"="police"](${bbox});
  way["amenity"="police"](${bbox});
);
out center;
`,
  },
  hospitals: {
    bbox: RMS_BBOX,
    query: (bbox) => `
[out:json][timeout:60];
(
  node["amenity"="hospital"](${bbox});
  way["amenity"="hospital"](${bbox});
  node["amenity"="clinic"]["emergency"="yes"](${bbox});
  way["amenity"="clinic"]["emergency"="yes"](${bbox});
);
out center;
`,
  },
  street_lamps: {
    bbox: SALVADOR_URBAN_BBOX,
    query: (bbox) => `
[out:json][timeout:90];
(
  node["highway"="street_lamp"](${bbox});
);
out body;
`,
  },
  commerce_24h: {
    bbox: RMS_BBOX,
    query: (bbox) => `
[out:json][timeout:60];
(
  node["opening_hours"="24/7"]["shop"](${bbox});
  way["opening_hours"="24/7"]["shop"](${bbox});
  node["opening_hours"="24/7"]["amenity"~"^(fuel|pharmacy|fast_food|restaurant|cafe|bar)$"](${bbox});
  way["opening_hours"="24/7"]["amenity"~"^(fuel|pharmacy|fast_food|restaurant|cafe|bar)$"](${bbox});
);
out center;
`,
  },
};

exports.fetchOsmInfra = onRequest(
  {
    region: "southamerica-east1",
    memory: "512MiB",
    timeoutSeconds: 300,
  },
  async (req, res) => {
    try {
      const requested = (req.query.kinds || "").toString().trim();
      const kinds = requested
        ? requested.split(",").map((k) => k.trim()).filter((k) => QUERIES[k])
        : Object.keys(QUERIES);

      if (kinds.length === 0) {
        res.status(400).json({
          error: "no valid kinds requested",
          available: Object.keys(QUERIES),
        });
        return;
      }

      const summary = await runInfraSync(kinds);
      res.status(200).json(summary);
    } catch (e) {
      logger.error(`OSM infra fetch falhou: ${e.message}`);
      res.status(500).json({ error: e.message });
    }
  },
);

// Tick semanal: segunda 04:30 (depois do cleanup diário e do osm-notes).
// Atualiza as 4 camadas em série; Overpass não gosta de paralelismo agressivo.
exports.syncOsmInfra = onSchedule(
  {
    schedule: "every monday 04:30",
    timeZone: "America/Bahia",
    region: "southamerica-east1",
    memory: "512MiB",
    timeoutSeconds: 540,
  },
  async () => {
    const summary = await runInfraSync(Object.keys(QUERIES));
    logger.info("OSM infra sync semanal concluído", { summary });
  },
);

async function runInfraSync(kinds) {
  const db = admin.firestore();
  const summary = {};
  for (const kind of kinds) {
    const spec = QUERIES[kind];
    const raw = await fetchOverpass(spec.query(spec.bbox));
    const items = parseInfra(raw, kind);
    await db.collection("osm").doc(kind).set({
      items,
      count: items.length,
      bbox: spec.bbox,
      fetchedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    summary[kind] = items.length;
    logger.info(`OSM ${kind} sincronizado: ${items.length} itens`);
  }
  return summary;
}

async function fetchOverpass(query) {
  const body = `data=${encodeURIComponent(query.trim())}`;
  const r = await fetch(OVERPASS_URL, {
    method: "POST",
    headers: {
      "Content-Type": "application/x-www-form-urlencoded",
      "User-Agent": "Faro/0.1 (+https://github.com/Maufloquet/faro)",
    },
    body,
  });
  if (!r.ok) {
    const text = await r.text();
    throw new Error(`Overpass ${r.status}: ${text.slice(0, 200)}`);
  }
  return r.json();
}

/**
 * Converte a resposta crua do Overpass numa lista compacta da categoria
 * pedida. Função pura — testável com fixtures.
 *
 * - Aceita `node` (lat/lon direto) e `way` (usa `center` retornado por
 *   `out center;`).
 * - Deduplica por id dentro da mesma chamada.
 * - Mantém só tags úteis pra UI por categoria.
 */
function parseInfra(raw, kind) {
  const elements = Array.isArray(raw?.elements) ? raw.elements : [];
  const seen = new Set();
  const items = [];
  for (const e of elements) {
    const coords = extractCoords(e);
    if (!coords) continue;
    const key = `${e.type}:${e.id}`;
    if (seen.has(key)) continue;
    seen.add(key);

    const tags = e.tags || {};
    items.push({
      id: e.id,
      type: e.type,
      lat: round5(coords.lat),
      lng: round5(coords.lng),
      name: tags.name || null,
      ...tagSubset(tags, kind),
    });
  }
  return items;
}

function extractCoords(e) {
  if (e.type === "node" && typeof e.lat === "number" && typeof e.lon === "number") {
    return { lat: e.lat, lng: e.lon };
  }
  if (
    e.type === "way" &&
    e.center &&
    typeof e.center.lat === "number" &&
    typeof e.center.lon === "number"
  ) {
    return { lat: e.center.lat, lng: e.center.lon };
  }
  return null;
}

/**
 * Mantém só as tags relevantes por categoria. Não confundir "ausente" com
 * "negativo" — propriedades opcionais ficam undefined em vez de false.
 */
function tagSubset(tags, kind) {
  switch (kind) {
    case "police":
      return {
        phone: tags.phone || tags["contact:phone"] || null,
        operator: tags.operator || null,
      };
    case "hospitals":
      return {
        emergency: tags.emergency === "yes" || undefined,
        operator: tags.operator || null,
        phone: tags.phone || tags["contact:phone"] || null,
      };
    case "street_lamps":
      // Postes não têm muito mais a oferecer além da localização.
      return {};
    case "commerce_24h":
      return {
        shop: tags.shop || null,
        amenity: tags.amenity || null,
        brand: tags.brand || null,
      };
    default:
      return {};
  }
}

function round5(n) {
  return Math.round(n * 1e5) / 1e5;
}

exports._internal = { parseInfra, QUERIES };
