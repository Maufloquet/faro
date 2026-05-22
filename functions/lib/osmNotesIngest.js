"use strict";

/**
 * Ingest diário de OpenStreetMap Notes — anotações geográficas que
 * moradores deixam no mapa público com pinpoint. Volume pequeno no
 * Brasil mas qualidade alta: quem usa OSM Notes em geral é mapeador
 * sério ou morador apontando algo concreto ("assalto recorrente nesta
 * esquina").
 *
 * Diferente do Overpass (que consulta a base mapeada), Notes tem API
 * própria de comentários geo-pinned. Endpoint:
 *   https://api.openstreetmap.org/api/0.6/notes/search?q=...&bbox=...
 *
 * Filtragem:
 *  - bbox da RMS (mesmo da osmFetch)
 *  - status "open" (não-resolvido)
 *  - keywords de segurança em PT (assalto, perigoso, roubo, violência…)
 *  - data do primeiro comentário ≤ 60 dias (notes antigas são silêncio
 *    bom — não queremos arrasto de coisas resolvidas há tempo)
 *
 * Saída: occurrences com source="osm_note" e peso editorial baixo
 * (0.35) — é dado anedótico, não confirmado. Aparece junto com mídia
 * mas com peso menor pra evitar dominar visualização.
 *
 * Custo: API OSM é grátis, sem auth, com rate limit cortês (~10k
 * req/dia compartilhado). Ingest diário usa ~10 reqs (uma por keyword).
 */

const admin = require("firebase-admin");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { logger } = require("firebase-functions/v2");
const ngeohash = require("ngeohash");

const OSM_SEARCH_URL = "https://api.openstreetmap.org/api/0.6/notes/search";

// Bbox RMS — mesmo da osmFetch (south, west, north, east).
// API OSM aceita "left,bottom,right,top" — convertemos.
const RMS_BBOX_OSM = "-38.65,-13.05,-38.20,-12.65"; // west,south,east,north

// Keywords PT (mais comuns em notes de segurança no Brasil).
// Cada query é independente — total ~9 fetches.
const KEYWORDS = [
  "assalto",
  "roubo",
  "perigoso",
  "violência",
  "tiroteio",
  "agressão",
  "criminoso",
  "atenção",
  "evitar",
];

// Tipo padrão pro mainReason quando não der pra inferir do texto.
const DEFAULT_REASON = "Outros";

// Mapeamento heurístico: se a nota mencionar uma keyword específica,
// inferimos a categoria do nosso TYPE_MAP. Reusa as mesmas chaves do
// newsIngest pra display consistente no app.
const REASON_FROM_KEYWORD = {
  assalto: "Roubo",
  roubo: "Roubo",
  tiroteio: "Tiroteio",
  violência: "Agressão",
  agressão: "Agressão",
  criminoso: "Outros",
  perigoso: "Outros",
  atenção: "Outros",
  evitar: "Outros",
};

const MAX_AGE_DAYS = 60;
const PESO_EDITORIAL = 0.35;
const SOURCE_ID = "osm_note";

/**
 * Função agendada — roda 1x por dia. Consulta cada keyword e grava
 * occurrences novas no Firestore, deduplicando pelo id da nota.
 */
exports.ingestOsmNotes = onSchedule(
  {
    schedule: "every day 03:30",
    timeZone: "America/Bahia",
    region: "southamerica-east1",
    memory: "256MiB",
    timeoutSeconds: 300,
  },
  async () => {
    const db = admin.firestore();
    const cutoff = Date.now() - MAX_AGE_DAYS * 24 * 60 * 60 * 1000;

    const stats = { fetched: 0, kept: 0, written: 0, skipped: 0 };
    const seen = new Set();

    // Paralelo: 9 fetches contra OSM API. fetchNotesForKeyword tem
    // try/catch interno e devolve [] em erro, então Promise.all é seguro.
    // OSM Notes API tem rate limit alto (~10k/dia compartilhado); 9 em
    // burst é negligível. Ganho: 9× menos wall time quando a API tá lenta.
    const allBatches = await Promise.all(
      KEYWORDS.map((k) => fetchNotesForKeyword(k))
    );

    for (const notes of allBatches) {
      stats.fetched += notes.length;

      for (const note of notes) {
        if (seen.has(note.id)) continue;
        seen.add(note.id);

        const createdAt = parseNoteDate(note);
        if (!createdAt || createdAt.getTime() < cutoff) {
          stats.skipped++;
          continue;
        }
        if (!isOpen(note)) {
          stats.skipped++;
          continue;
        }
        if (!hasSecurityKeyword(note)) {
          stats.skipped++;
          continue;
        }

        stats.kept++;

        const docId = `osmnote-${note.id}`;
        const reason = inferReason(note);
        const ref = db.collection("occurrences").doc(docId);

        // idempotente — set com merge sobrescreve se ID existe.
        await ref.set(
          {
            latitude: note.lat,
            longitude: note.lon,
            geohash: ngeohash.encode(note.lat, note.lon, 8),
            date: admin.firestore.Timestamp.fromDate(createdAt),
            expiresAt: admin.firestore.Timestamp.fromDate(
              new Date(createdAt.getTime() + MAX_AGE_DAYS * 24 * 60 * 60 * 1000)
            ),
            state: "Bahia",
            city: null, // OSM Notes não trazem city; resolução ficou pra V2
            neighborhood: null,
            geocodeMethod: "osm-note",
            mainReason: reason,
            eventKey: null, // não corroboramos com mídia — fonte distinta
            source: SOURCE_ID,
            sourceProvider: "osm",
            sourceName: "OpenStreetMap (anotação local)",
            weight: PESO_EDITORIAL,
            externalUrl: `https://www.openstreetmap.org/note/${note.id}`,
            externalTitle: snippetFromNote(note),
            confidence: null,
            corroborationCount: 0,
            ingestedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        );
        stats.written++;
      }
    }

    logger.info(
      `osm-notes ingest · fetched=${stats.fetched} kept=${stats.kept} ` +
        `written=${stats.written} skipped=${stats.skipped}`
    );
    return stats;
  }
);

/**
 * Busca OSM notes pra uma keyword. Retorna array de notes normalizadas.
 * Falha silenciosa: se a API der erro, retorna [] pra não derrubar o batch.
 */
async function fetchNotesForKeyword(keyword) {
  try {
    const url =
      `${OSM_SEARCH_URL}?q=${encodeURIComponent(keyword)}` +
      `&bbox=${RMS_BBOX_OSM}&closed=0&limit=100&format=json`;
    const r = await fetch(url, {
      headers: { "User-Agent": "Faro/0.1 (https://github.com/maufloquet/faro)" },
    });
    if (!r.ok) {
      logger.warn(`OSM notes ${r.status} pra "${keyword}"`);
      return [];
    }
    const data = await r.json();
    const features = Array.isArray(data?.features) ? data.features : [];
    return features.map((f) => normalizeNote(f, keyword));
  } catch (e) {
    logger.error(`OSM notes erro fetch "${keyword}"`, e);
    return [];
  }
}

function normalizeNote(feature, keyword) {
  const coords = feature?.geometry?.coordinates || [null, null];
  const props = feature?.properties || {};
  return {
    id: props.id,
    lat: coords[1],
    lon: coords[0],
    status: props.status,
    comments: props.comments || [],
    matchedKeyword: keyword,
  };
}

function parseNoteDate(note) {
  const first = note.comments[0];
  if (!first || !first.date) return null;
  // OSM date format: "2024-05-18 12:34:56 UTC"
  const d = new Date(first.date.replace(" UTC", "Z").replace(" ", "T"));
  return isNaN(d.getTime()) ? null : d;
}

function isOpen(note) {
  return note.status === "open";
}

/**
 * Defesa contra falso positivo: o `q=` da API faz fuzzy match — pode
 * trazer notes que mencionam a keyword em contexto não-segurança ("rota
 * de ônibus assalto-difícil"). Confirma a presença de pelo menos uma
 * das keywords-âncora no texto do primeiro comentário.
 */
function hasSecurityKeyword(note) {
  const text = (note.comments[0]?.text || "").toLowerCase();
  return KEYWORDS.some((k) => text.includes(k));
}

function inferReason(note) {
  const text = (note.comments[0]?.text || "").toLowerCase();
  for (const k of Object.keys(REASON_FROM_KEYWORD)) {
    if (text.includes(k)) return REASON_FROM_KEYWORD[k];
  }
  return DEFAULT_REASON;
}

function snippetFromNote(note) {
  const raw = note.comments[0]?.text || "";
  return raw.length > 140 ? `${raw.slice(0, 137)}...` : raw;
}

// Exportado pra teste unitário
exports._internal = {
  hasSecurityKeyword,
  inferReason,
  parseNoteDate,
  isOpen,
  KEYWORDS,
};
