"use strict";

const { test } = require("node:test");
const assert = require("node:assert/strict");

const { _internal } = require("../lib/expireReports");
const { isExpired, chunk } = _internal;

const ts = (ms) => ({ toMillis: () => ms });
const now = 1_000_000;

test("pendente com expiresAt no passado expira", () => {
  assert.equal(isExpired({ status: "pending", expiresAt: ts(now - 1) }, now), true);
});

test("pendente com expiresAt no futuro não expira", () => {
  assert.equal(isExpired({ status: "pending", expiresAt: ts(now + 1000) }, now), false);
});

test("confirmado nunca expira por aqui", () => {
  assert.equal(isExpired({ status: "confirmed", expiresAt: ts(now - 1) }, now), false);
});

test("rejeitado/expirado não reexpira", () => {
  assert.equal(isExpired({ status: "rejected", expiresAt: ts(now - 1) }, now), false);
  assert.equal(isExpired({ status: "expired", expiresAt: ts(now - 1) }, now), false);
});

test("sem expiresAt não expira", () => {
  assert.equal(isExpired({ status: "pending" }, now), false);
  assert.equal(isExpired({ status: "pending", expiresAt: null }, now), false);
});

test("aceita Date além de Timestamp", () => {
  assert.equal(isExpired({ status: "pending", expiresAt: new Date(now - 1) }, now), true);
  assert.equal(isExpired({ status: "pending", expiresAt: new Date(now + 1) }, now), false);
});

test("chunk parte em lotes", () => {
  assert.deepEqual(chunk([1, 2, 3, 4, 5], 2), [[1, 2], [3, 4], [5]]);
  assert.deepEqual(chunk([], 3), []);
});
