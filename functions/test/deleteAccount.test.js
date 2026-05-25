"use strict";

const { test } = require("node:test");
const assert = require("node:assert/strict");

const { _internal } = require("../lib/deleteAccount");
const { chunk, BATCH_LIMIT } = _internal;

test("chunk parte em lotes do tamanho pedido", () => {
  const r = chunk([1, 2, 3, 4, 5], 2);
  assert.deepEqual(r, [[1, 2], [3, 4], [5]]);
});

test("chunk com array vazio devolve vazio", () => {
  assert.deepEqual(chunk([], 10), []);
});

test("chunk com size maior que o array devolve um lote só", () => {
  assert.deepEqual(chunk([1, 2, 3], 500), [[1, 2, 3]]);
});

test("chunk com array múltiplo exato do size não deixa lote vazio", () => {
  const r = chunk([1, 2, 3, 4], 2);
  assert.deepEqual(r, [[1, 2], [3, 4]]);
});

test("chunk rejeita size <= 0 (evita loop infinito)", () => {
  assert.throws(() => chunk([1, 2], 0), RangeError);
  assert.throws(() => chunk([1, 2], -1), RangeError);
});

test("BATCH_LIMIT respeita o teto do Firestore de 500", () => {
  assert.ok(BATCH_LIMIT <= 500);
  assert.ok(BATCH_LIMIT > 0);
});

test("um lote de exatamente BATCH_LIMIT docs vira um único batch", () => {
  const docs = Array.from({ length: BATCH_LIMIT }, (_, i) => i);
  assert.equal(chunk(docs, BATCH_LIMIT).length, 1);
});

test("BATCH_LIMIT + 1 docs viram dois batches", () => {
  const docs = Array.from({ length: BATCH_LIMIT + 1 }, (_, i) => i);
  const groups = chunk(docs, BATCH_LIMIT);
  assert.equal(groups.length, 2);
  assert.equal(groups[0].length, BATCH_LIMIT);
  assert.equal(groups[1].length, 1);
});
