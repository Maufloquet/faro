"use strict";

/**
 * Backfill manual de embeddings em ocorrências históricas.
 *
 * Lê /occurrences filtrando docs SEM `embedding`, monta o texto canônico
 * (título da matéria quando há, ou bairro + cidade + motivo como fallback),
 * embeda em batch (até 100 por chamada Gemini), grava.
 *
 * Roda 1x à mão depois do deploy inicial pra cobrir o histórico de docs
 * gravados antes do pipeline ganhar embedding. Em estado estacionário,
 * cada novo doc já entra com embedding via `newsIngest`.
 *
 * Como chamar (admin do projeto via Cloud Console "Testar", ou:
 *   curl -X POST -H "Authorization: Bearer $(gcloud auth print-identity-token)" \
 *     "$URL?limit=500&dryRun=false"
 * ):
 *   - `limit` (opcional, default 500): teto de docs a processar nesta call.
 *   - `dryRun` (opcional, default false): se true, conta candidatos sem gravar.
 *
 * Idempotente: roda 2x, segunda chamada não tem nada pra fazer (filtro
 * descarta docs já cobertos). Custo: ~grátis (Gemini free tier cobre).
 */

const admin = require("firebase-admin");
const { onRequest } = require("firebase-functions/v2/https");
const { logger } = require("firebase-functions/v2");

const {
  embedTexts,
  EMBEDDING_DIM,
  EMBEDDING_PROVIDER,
} = require("./embedClient");

const DEFAULT_LIMIT = 500;
const HARD_LIMIT = 2000;
const BATCH_SIZE = 50;
const SCAN_BATCH = 200;

exports.backfillEmbeddings = onRequest(
  {
    region: "southamerica-east1",
    memory: "512MiB",
    timeoutSeconds: 540,
    secrets: ["GEMINI_API_KEY"],
  },
  async (req, res) => {
    const apiKey = process.env.GEMINI_API_KEY;
    if (!apiKey) {
      res.status(500).json({ error: "GEMINI_API_KEY ausente" });
      return;
    }

    const limit = Math.min(
      HARD_LIMIT,
      parseInt(req.query.limit || DEFAULT_LIMIT, 10) || DEFAULT_LIMIT,
    );
    const dryRun = req.query.dryRun === "true";

    const db = admin.firestore();
    const candidates = await collectCandidates(db, limit);

    if (dryRun) {
      res.status(200).json({
        dryRun: true,
        candidates: candidates.length,
        sample: candidates.slice(0, 5).map((c) => c.id),
      });
      return;
    }

    let embedded = 0;
    let failed = 0;
    for (let i = 0; i < candidates.length; i += BATCH_SIZE) {
      const chunk = candidates.slice(i, i + BATCH_SIZE);
      const texts = chunk.map((c) => canonicalText(c.data));
      try {
        const vectors = await embedTexts(texts, { apiKey });
        const batch = db.batch();
        for (let j = 0; j < chunk.length; j++) {
          const vec = vectors[j];
          if (!vec || vec.length !== EMBEDDING_DIM) {
            failed++;
            continue;
          }
          batch.update(chunk[j].ref, {
            embedding: admin.firestore.FieldValue.vector(vec),
            embeddingProvider: EMBEDDING_PROVIDER,
            embeddingDim: EMBEDDING_DIM,
            embeddingBackfilledAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          embedded++;
        }
        await batch.commit();
        logger.info(`backfill chunk ${i / BATCH_SIZE + 1}: +${chunk.length} docs`);
      } catch (e) {
        failed += chunk.length;
        logger.error(`backfill chunk falhou: ${e.message}`);
      }
    }

    res.status(200).json({
      candidates: candidates.length,
      embedded,
      failed,
      provider: EMBEDDING_PROVIDER,
    });
  },
);

/**
 * Pega até `limit` docs sem embedding. Firestore não tem operador "field
 * doesn't exist" eficiente, então paginamos por data DESC e filtramos
 * client-side. Como a janela inteira tem ~287 docs hoje (ver memória do
 * projeto), o overhead é insignificante.
 */
async function collectCandidates(db, limit) {
  const candidates = [];
  let last = null;
  while (candidates.length < limit) {
    let q = db.collection("occurrences").orderBy("date", "desc").limit(SCAN_BATCH);
    if (last) q = q.startAfter(last);
    const snap = await q.get();
    if (snap.empty) break;
    for (const doc of snap.docs) {
      if (candidates.length >= limit) break;
      const data = doc.data();
      if (data.embedding) continue;
      candidates.push({ id: doc.id, ref: doc.ref, data });
    }
    last = snap.docs[snap.docs.length - 1];
    if (snap.size < SCAN_BATCH) break;
  }
  return candidates;
}

/**
 * Texto canônico pra embedar. Prioriza o que melhor representa o conteúdo
 * editorial — `externalTitle` traz o título da matéria, melhor sinal
 * semântico. Quando não tem (Fogo Cruzado, OSM Notes), monta um descritor
 * a partir do bairro + cidade + motivo, que é o mínimo viável pra dedup
 * cross-source.
 */
function canonicalText(data) {
  const title = (data.externalTitle || "").trim();
  if (title.length > 0) {
    return title.slice(0, 2000);
  }
  const parts = [
    data.mainReason,
    data.neighborhood,
    data.city,
    data.state,
  ].filter(Boolean);
  return parts.join(" — ").slice(0, 2000) || "ocorrência sem descrição";
}

exports._internal = { canonicalText };
