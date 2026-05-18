"use strict";

/**
 * HTTP function manual one-shot: puxa pontos de ônibus da RMS (Salvador +
 * Camaçari + Lauro de Freitas + Simões Filho) via OpenStreetMap Overpass
 * API e salva como single doc em /osm/bus_stops.
 *
 * Por que pontos de ônibus primeiro: audiência "passageiro de ônibus" é a
 * mais numerosa e a mais esquecida por soluções de mobilidade urbana. Ver
 * docs/roadmap_features.md §"Passageiros de ônibus".
 *
 * Custo: Overpass é grátis, sem auth. Limite ~10k queries/dia compartilhado.
 * Nosso uso é manual (raro), folga absoluta. Cache server-side evita app
 * martelar Overpass — todos consomem do Firestore.
 *
 * Como invocar (admin):
 *   curl -X POST -H "Authorization: Bearer <token>" "<function-url>"
 *
 * Idempotente: roda 2x, sobrescreve com snapshot fresco.
 */

const admin = require("firebase-admin");
const { onRequest } = require("firebase-functions/v2/https");
const { logger } = require("firebase-functions/v2");

const OVERPASS_URL = "https://overpass-api.de/api/interpreter";

// Bbox da RMS — south, west, north, east. Margem larga pra cobrir Camaçari ao norte
// e a ponta sul de Salvador. ~12-13° S, ~38-39° W.
const RMS_BBOX = "-13.05,-38.65,-12.65,-38.20";

const QUERY_BUS_STOPS = `
[out:json][timeout:60];
(
  node["highway"="bus_stop"](${RMS_BBOX});
  node["public_transport"="platform"]["bus"="yes"](${RMS_BBOX});
);
out body;
`;

exports.fetchOsmBusStops = onRequest(
  {
    region: "southamerica-east1",
    memory: "512MiB",
    timeoutSeconds: 120,
  },
  async (req, res) => {
    try {
      const raw = await fetchOverpass(QUERY_BUS_STOPS);
      const stops = parseBusStops(raw);

      const db = admin.firestore();
      await db.collection("osm").doc("bus_stops").set({
        stops,
        count: stops.length,
        bbox: RMS_BBOX,
        fetchedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      logger.info(`OSM bus_stops sincronizado: ${stops.length} pontos`);
      res.status(200).json({ count: stops.length });
    } catch (e) {
      logger.error(`OSM fetch falhou: ${e.message}`);
      res.status(500).json({ error: e.message });
    }
  },
);

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
 * Converte a resposta crua do Overpass numa lista compacta de pontos de
 * ônibus prontos pra app. Função pura — testável com fixtures.
 *
 * Deduplica por id (alguns pontos aparecem como bus_stop E platform).
 */
function parseBusStops(raw) {
  const elements = Array.isArray(raw?.elements) ? raw.elements : [];
  const seen = new Set();
  const stops = [];
  for (const e of elements) {
    if (e.type !== "node") continue;
    if (typeof e.lat !== "number" || typeof e.lon !== "number") continue;
    if (seen.has(e.id)) continue;
    seen.add(e.id);

    const tags = e.tags || {};
    stops.push({
      id: e.id,
      lat: round5(e.lat),
      lng: round5(e.lon),
      name: tags.name || null,
      shelter: tags.shelter === "yes",
      bench: tags.bench === "yes",
      lit: tags.lit === "yes",
    });
  }
  return stops;
}

function round5(n) {
  return Math.round(n * 1e5) / 1e5;
}

exports._internal = { parseBusStops, QUERY_BUS_STOPS };
