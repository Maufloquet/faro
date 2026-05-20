"use strict";

const { describe, it } = require("node:test");
const assert = require("node:assert/strict");

const { _internal } = require("../lib/contestationAggregator");
const { aggregate, CONTESTATION_THRESHOLD } = _internal;

describe("contestationAggregator.aggregate", () => {
  it("conta total e usuários distintos corretamente", () => {
    const r = aggregate([
      { submittedBy: "u1", reason: "imprecise" },
      { submittedBy: "u2", reason: "imprecise" },
      { submittedBy: "u3", reason: "notHappened" },
    ]);
    assert.equal(r.contestationCount, 3);
    assert.equal(r.contestationDistinctUsers, 3);
    assert.deepEqual(r.contestationReasonBreakdown, {
      imprecise: 2,
      notHappened: 1,
    });
  });

  it("um mesmo usuário contestando várias vezes conta como 1 distinto", () => {
    const r = aggregate([
      { submittedBy: "u1", reason: "imprecise" },
      { submittedBy: "u1", reason: "imprecise" },
      { submittedBy: "u1", reason: "notHappened" },
      { submittedBy: "u1", reason: "exaggerated" },
    ]);
    assert.equal(r.contestationCount, 4);
    assert.equal(r.contestationDistinctUsers, 1);
  });

  it(
    `marca contested=true quando distinct users >= ${CONTESTATION_THRESHOLD}`,
    () => {
      const r = aggregate([
        { submittedBy: "u1", reason: "imprecise" },
        { submittedBy: "u2", reason: "imprecise" },
        { submittedBy: "u3", reason: "imprecise" },
      ]);
      assert.equal(r.contested, true);
    },
  );

  it(
    `mantém contested=false abaixo do threshold (${CONTESTATION_THRESHOLD})`,
    () => {
      const r = aggregate([
        { submittedBy: "u1", reason: "imprecise" },
        { submittedBy: "u2", reason: "imprecise" },
      ]);
      assert.equal(r.contested, false);
      assert.equal(r.contestationDistinctUsers, 2);
    },
  );

  it("não bloqueia em entries sem submittedBy nem sem reason", () => {
    const r = aggregate([
      { reason: "imprecise" }, // sem submittedBy
      { submittedBy: "u1" }, // sem reason
      { submittedBy: "u2", reason: "" }, // reason vazio
      null, // entry nula
    ]);
    assert.equal(r.contestationCount, 4);
    assert.equal(r.contestationDistinctUsers, 2);
    assert.deepEqual(r.contestationReasonBreakdown, { imprecise: 1 });
  });

  it("lista vazia retorna zeros", () => {
    const r = aggregate([]);
    assert.equal(r.contestationCount, 0);
    assert.equal(r.contestationDistinctUsers, 0);
    assert.equal(r.contested, false);
    assert.deepEqual(r.contestationReasonBreakdown, {});
  });
});
