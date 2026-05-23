"use strict";

const { test } = require("node:test");
const assert = require("node:assert/strict");

const { embedTexts, EMBEDDING_DIM, _internal } = require("../lib/embedClient");
const { buildBatchRequest, parseBatchResponse } = _internal;

test("buildBatchRequest produz payload no formato batchEmbedContents", () => {
  const body = buildBatchRequest(["foo", "bar"]);
  assert.equal(body.requests.length, 2);
  assert.equal(body.requests[0].model, "models/text-embedding-004");
  assert.equal(body.requests[0].content.parts[0].text, "foo");
  assert.equal(body.requests[0].taskType, "RETRIEVAL_DOCUMENT");
});

test("parseBatchResponse extrai vetores na ordem", () => {
  const fakeVec1 = new Array(EMBEDDING_DIM).fill(0.1);
  const fakeVec2 = new Array(EMBEDDING_DIM).fill(0.2);
  const result = parseBatchResponse({
    embeddings: [{ values: fakeVec1 }, { values: fakeVec2 }],
  });
  assert.equal(result.length, 2);
  assert.equal(result[0][0], 0.1);
  assert.equal(result[1][0], 0.2);
});

test("parseBatchResponse rejeita dim errada", () => {
  assert.throws(
    () => parseBatchResponse({ embeddings: [{ values: [1, 2, 3] }] }),
    /embedding\[0\] inválido/,
  );
});

test("parseBatchResponse rejeita resposta sem embeddings", () => {
  assert.throws(
    () => parseBatchResponse({ candidates: [] }),
    /sem campo `embeddings`/,
  );
});

test("embedTexts exige apiKey", async () => {
  await assert.rejects(
    () => embedTexts(["foo"], { apiKey: null }),
    /apiKey ausente/,
  );
});

test("embedTexts retorna vetores quando a API responde ok", async () => {
  const dim = EMBEDDING_DIM;
  const fakeFetch = async () => ({
    ok: true,
    status: 200,
    json: async () => ({
      embeddings: [{ values: new Array(dim).fill(0.5) }],
    }),
    text: async () => "",
  });
  const out = await embedTexts(["alguma notícia"], {
    apiKey: "fake",
    fetcher: fakeFetch,
  });
  assert.equal(out.length, 1);
  assert.equal(out[0].length, dim);
});

test("embedTexts preserva ordem entre chunks de tamanho maior que MAX_BATCH", async () => {
  // 150 itens forçam 2 chunks (100 + 50). Cada item recebe um vetor com
  // um sinal único pra checar ordem.
  const items = Array.from({ length: 150 }, (_, i) => `item-${i}`);
  let callIndex = 0;
  const fakeFetch = async (url, init) => {
    const body = JSON.parse(init.body);
    const vectors = body.requests.map((req) => {
      const id = parseInt(req.content.parts[0].text.split("-")[1], 10);
      const v = new Array(EMBEDDING_DIM).fill(0);
      v[0] = id;
      return { values: v };
    });
    callIndex++;
    return {
      ok: true,
      status: 200,
      json: async () => ({ embeddings: vectors }),
      text: async () => "",
    };
  };
  const out = await embedTexts(items, { apiKey: "fake", fetcher: fakeFetch });
  assert.equal(out.length, 150);
  for (let i = 0; i < 150; i++) {
    assert.equal(out[i][0], i, `ordem do vetor ${i}`);
  }
  assert.equal(callIndex, 2); // 2 chunks
});

test("embedTexts retorna [] pra input vazio", async () => {
  const out = await embedTexts([], { apiKey: "fake" });
  assert.deepEqual(out, []);
});
