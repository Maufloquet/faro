"use strict";

/**
 * Wrapper sobre o endpoint `text-embedding-004` da Google Generative AI.
 *
 * Por que esse modelo:
 *   - 768 dimensões — cabe no Firestore Vector Search (limite 2048).
 *   - Multilingual: cobre PT-BR sem fine-tune.
 *   - Free tier amplo (1500 RPM) → news ingest atual processa ~50 itens/dia,
 *     folga absoluta. Mesmo em 5k itens/dia, ainda cabe.
 *
 * O Faro usa esse vetor pra dois propósitos:
 *   1. Dedup semântico cross-source (mesma matéria em portais diferentes
 *      vira UMA ocorrência corroborada, não 5).
 *   2. Clustering em narrativas semanais ("onda de assaltos em Garcia").
 *
 * REST direto via fetch (sem SDK) — uma dep a menos pra manter atualizada.
 *
 * Falha graciosa: erros bubblam, caller decide se grava sem embedding ou
 * pula. Nunca derruba o pipeline de news.
 */

const { logger } = require("firebase-functions/v2");

const MODEL = "models/text-embedding-004";
const DIM = 768;
const BATCH_ENDPOINT =
  "https://generativelanguage.googleapis.com/v1beta/" +
  MODEL +
  ":batchEmbedContents";
const SINGLE_ENDPOINT =
  "https://generativelanguage.googleapis.com/v1beta/" +
  MODEL +
  ":embedContent";

// Tarefa: pra qual uso o embedding serve. RETRIEVAL_DOCUMENT é a escolha
// certa pra dedup/clustering (queremos similaridade entre documentos do
// mesmo tipo). Mais detalhes:
// https://ai.google.dev/api/embeddings#tasktype
const TASK_TYPE = "RETRIEVAL_DOCUMENT";

const MAX_BATCH = 100; // limite atual da API
const MAX_RETRIES = 3;

/**
 * Embeda uma lista de textos. Retorna array de Float32Array (mesma ordem).
 *
 * @param {string[]} texts
 * @param {{apiKey: string, fetcher?: typeof fetch}} opts
 * @returns {Promise<Array<number[]>>}
 */
async function embedTexts(texts, { apiKey, fetcher = fetch } = {}) {
  if (!apiKey) throw new Error("embedClient: apiKey ausente (GEMINI_API_KEY)");
  if (!Array.isArray(texts) || texts.length === 0) return [];

  const cleaned = texts.map((t) => (typeof t === "string" ? t.trim() : ""));
  const out = new Array(cleaned.length);

  // Chunks de até MAX_BATCH. Index-aware pra preservar ordem do input.
  for (let i = 0; i < cleaned.length; i += MAX_BATCH) {
    const chunk = cleaned.slice(i, i + MAX_BATCH);
    const body = buildBatchRequest(chunk);
    const result = await callWithRetry(BATCH_ENDPOINT, apiKey, body, fetcher);
    const vectors = parseBatchResponse(result);
    if (vectors.length !== chunk.length) {
      throw new Error(
        `embedClient: resposta com ${vectors.length} vetores pra ${chunk.length} inputs`,
      );
    }
    for (let j = 0; j < vectors.length; j++) {
      out[i + j] = vectors[j];
    }
  }
  return out;
}

/**
 * Forma o payload do `batchEmbedContents`. Função pura, testável sem rede.
 */
function buildBatchRequest(texts) {
  return {
    requests: texts.map((text) => ({
      model: MODEL,
      content: { parts: [{ text }] },
      taskType: TASK_TYPE,
    })),
  };
}

/**
 * Extrai os vetores na ordem da resposta. Lança se algum item vier sem
 * `values`. Função pura — testes mockam o response.
 */
function parseBatchResponse(json) {
  const embeddings = json && json.embeddings;
  if (!Array.isArray(embeddings)) {
    throw new Error("embedClient: resposta sem campo `embeddings`");
  }
  return embeddings.map((e, i) => {
    const v = e && e.values;
    if (!Array.isArray(v) || v.length !== DIM) {
      throw new Error(
        `embedClient: embedding[${i}] inválido (dim=${v ? v.length : "?"})`,
      );
    }
    return v;
  });
}

async function callWithRetry(url, apiKey, body, fetcher) {
  let lastErr;
  for (let attempt = 0; attempt < MAX_RETRIES; attempt++) {
    try {
      const r = await fetcher(`${url}?key=${apiKey}`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(body),
      });
      if (r.status === 429 || r.status >= 500) {
        // Backoff exponencial: 500ms, 1.5s, 4.5s
        await sleep(500 * 3 ** attempt);
        lastErr = new Error(`embedClient HTTP ${r.status}`);
        continue;
      }
      if (!r.ok) {
        const text = await r.text().catch(() => "");
        throw new Error(
          `embedClient: HTTP ${r.status} — ${text.slice(0, 200)}`,
        );
      }
      return await r.json();
    } catch (e) {
      lastErr = e;
      logger.warn(`embedClient tentativa ${attempt + 1} falhou: ${e.message}`);
      await sleep(500 * 3 ** attempt);
    }
  }
  throw lastErr || new Error("embedClient: falha após retries");
}

function sleep(ms) {
  return new Promise((res) => setTimeout(res, ms));
}

exports.embedTexts = embedTexts;
exports.MODEL_ID = MODEL;
exports.EMBEDDING_DIM = DIM;
exports.EMBEDDING_PROVIDER = "gemini-text-embedding-004";
exports._internal = { buildBatchRequest, parseBatchResponse };
