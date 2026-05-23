"use strict";

/**
 * Dedup semântico cross-source.
 *
 * Usa Firestore Vector Search (`findNearest`) pra achar o doc mais
 * próximo de um embedding dentro de uma janela temporal. Threshold de
 * distância cosseno é conservador (0.12 → similaridade ≥ 0.88) — o
 * comportamento preferido é falso negativo (cria duplicata) a falso
 * positivo (mescla relatos diferentes).
 *
 * Usado por `newsIngest` e `fogoCruzadoSync`. Quando os dois ingerem o
 * mesmo evento (matéria de jornal + registro do Fogo Cruzado do mesmo
 * tiroteio), o segundo acha o primeiro por proximidade semântica e anexa
 * corroboração em vez de criar uma 2ª ocorrência.
 *
 * Requer o vector index em `occurrences.embedding` (declarado em
 * `infra/firestore.indexes.json`). Enquanto o index está building, a
 * query lança `FAILED_PRECONDITION` — o caller deve capturar e usar
 * fallback (eventKey).
 */

const admin = require("firebase-admin");

const DEFAULT_WINDOW_HOURS = 6;
const DEFAULT_MAX_DISTANCE = 0.12; // ≈ similaridade cosseno 0.88
const DEFAULT_LIMIT = 5;

/**
 * Busca o doc mais próximo semanticamente de `embedding`, restrito a
 * `[pubDate - windowHours, pubDate + windowHours]`. Retorna o
 * DocumentSnapshot do match (já com `_vector_distance` legível via
 * `.get('_vector_distance')`) ou null se nada cair no threshold.
 *
 * @param {FirebaseFirestore.Firestore} db
 * @param {number[]} embedding vetor do item candidato
 * @param {Date} pubDate centro da janela temporal
 * @param {{
 *   windowHours?: number,
 *   maxDistance?: number,
 *   limit?: number,
 *   collection?: string,
 *   excludeId?: string,
 * }} [opts]
 */
async function findSemanticDuplicate(db, embedding, pubDate, opts = {}) {
  const windowHours = opts.windowHours ?? DEFAULT_WINDOW_HOURS;
  const maxDistance = opts.maxDistance ?? DEFAULT_MAX_DISTANCE;
  const limit = opts.limit ?? DEFAULT_LIMIT;
  const collection = opts.collection ?? "occurrences";

  const windowMs = windowHours * 60 * 60 * 1000;
  const since = new Date(pubDate.getTime() - windowMs);
  const until = new Date(pubDate.getTime() + windowMs);

  const snap = await db
    .collection(collection)
    .where("date", ">=", admin.firestore.Timestamp.fromDate(since))
    .where("date", "<=", admin.firestore.Timestamp.fromDate(until))
    .findNearest({
      vectorField: "embedding",
      queryVector: admin.firestore.FieldValue.vector(embedding),
      limit,
      distanceMeasure: "COSINE",
      distanceResultField: "_vector_distance",
    })
    .get();

  if (snap.empty) return null;

  // Itera porque o primeiro pode ser o próprio item (ex.: re-ingest do
  // mesmo doc); pula via `excludeId`.
  for (const doc of snap.docs) {
    if (opts.excludeId && doc.id === opts.excludeId) continue;
    const dist = doc.get("_vector_distance");
    if (typeof dist !== "number") continue;
    if (dist <= maxDistance) return doc;
  }
  return null;
}

exports.findSemanticDuplicate = findSemanticDuplicate;
exports.DEFAULT_MAX_DISTANCE = DEFAULT_MAX_DISTANCE;
exports.DEFAULT_WINDOW_HOURS = DEFAULT_WINDOW_HOURS;
