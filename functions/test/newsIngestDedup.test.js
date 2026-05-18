"use strict";

const { describe, it } = require("node:test");
const assert = require("node:assert/strict");

const { _internal } = require("../lib/newsIngest");
const { findCorroboratableDoc, DEDUP_WINDOW_HOURS } = _internal;

/**
 * Fake de Firestore que captura os filtros aplicados e devolve docs
 * fornecidos pelo teste se a query bate. Não testa Firestore real — testa
 * que estamos passando os argumentos certos pro driver.
 */
function makeFakeDb(docsByEventKey) {
  const calls = [];

  const collection = (name) => ({
    where(field, op, value) {
      const filters = [{ field, op, value }];
      return chain(filters);
    },
  });

  function chain(filters) {
    return {
      where(field, op, value) {
        return chain([...filters, { field, op, value }]);
      },
      limit(n) {
        return {
          async get() {
            calls.push({ filters, limit: n });
            const eventKeyFilter = filters.find((f) => f.field === "eventKey");
            const matchKey = eventKeyFilter?.value;
            const found = (docsByEventKey[matchKey] || []).slice(0, n);
            return {
              empty: found.length === 0,
              docs: found,
            };
          },
        };
      },
    };
  }

  return { collection, _calls: calls };
}

const fakeTimestamp = (date) => ({
  toMillis: () => date.getTime(),
});

describe("newsIngest.findCorroboratableDoc", () => {
  it("retorna null quando eventKey é null (não deduplicar sem chave)", async () => {
    const db = makeFakeDb({});
    const r = await findCorroboratableDoc(db, null, new Date());
    assert.equal(r, null);
  });

  it("constrói query com eventKey == e janela date >= since && <= until", async () => {
    const db = makeFakeDb({});
    const pubDate = new Date("2026-05-17T12:00:00Z");
    await findCorroboratableDoc(db, "salvador|piraja|tiroteio", pubDate);

    assert.equal(db._calls.length, 1);
    const { filters, limit } = db._calls[0];
    assert.equal(limit, 1);

    const eqEventKey = filters.find((f) => f.field === "eventKey" && f.op === "==");
    assert.ok(eqEventKey, "deveria filtrar por eventKey ==");
    assert.equal(eqEventKey.value, "salvador|piraja|tiroteio");

    const gte = filters.find((f) => f.field === "date" && f.op === ">=");
    const lte = filters.find((f) => f.field === "date" && f.op === "<=");
    assert.ok(gte && lte, "deveria filtrar date com >= e <=");

    const windowMs = DEDUP_WINDOW_HOURS * 60 * 60 * 1000;
    assert.equal(
      gte.value.toDate().getTime(),
      pubDate.getTime() - windowMs,
      "since = pubDate - 6h",
    );
    assert.equal(
      lte.value.toDate().getTime(),
      pubDate.getTime() + windowMs,
      "until = pubDate + 6h",
    );
  });

  it("retorna o doc quando há match na janela", async () => {
    const existingDoc = {
      id: "media-abc",
      data: () => ({ source: "media", weight: 0.35, expiresAt: fakeTimestamp(new Date()) }),
    };
    const db = makeFakeDb({ "salvador|piraja|tiroteio": [existingDoc] });
    const r = await findCorroboratableDoc(db, "salvador|piraja|tiroteio", new Date());
    assert.equal(r, existingDoc);
  });

  it("retorna null quando não há match (key inédita)", async () => {
    const db = makeFakeDb({});
    const r = await findCorroboratableDoc(db, "salvador|itapua|roubo", new Date());
    assert.equal(r, null);
  });
});
