"use strict";

const { test } = require("node:test");
const assert = require("node:assert/strict");

const { _internal } = require("../lib/reportReputation");
const { reputationToWeight, BASE_WEIGHT, MIN_WEIGHT, MAX_WEIGHT } = _internal;

test("score 0 → peso base", () => {
  assert.equal(reputationToWeight(0), BASE_WEIGHT);
});

test("score positivo sobe o peso", () => {
  assert.ok(reputationToWeight(3) > BASE_WEIGHT);
});

test("score alto satura no teto", () => {
  assert.equal(reputationToWeight(1000), MAX_WEIGHT);
});

test("score negativo desce até o piso", () => {
  assert.equal(reputationToWeight(-1000), MIN_WEIGHT);
});

test("peso fica sempre dentro de [MIN, MAX]", () => {
  for (const s of [-50, -5, -1, 0, 1, 5, 50, 500]) {
    const w = reputationToWeight(s);
    assert.ok(w >= MIN_WEIGHT && w <= MAX_WEIGHT, `score ${s} → ${w}`);
  }
});

test("score não-numérico é tratado como 0", () => {
  assert.equal(reputationToWeight(undefined), BASE_WEIGHT);
  assert.equal(reputationToWeight(null), BASE_WEIGHT);
  assert.equal(reputationToWeight(NaN), BASE_WEIGHT);
  assert.equal(reputationToWeight("xpto"), BASE_WEIGHT);
});
