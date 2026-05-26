"use strict";

const { test } = require("node:test");
const assert = require("node:assert/strict");

const { _internal } = require("../lib/reportVoteAggregator");
const { aggregateVotes, buildPromotedOccurrence, CONFIRM_THRESHOLD } = _internal;

const author = "autor-uid";

test("sem votos: pending, contagens zeradas", () => {
  const r = aggregateVotes([], author);
  assert.deepEqual(r, { confirmCount: 0, contestCount: 0, status: "pending" });
});

test("ignora o voto do próprio autor", () => {
  const r = aggregateVotes(
    [{ id: author, vote: "confirm" }, { id: "x", vote: "confirm" }],
    author,
  );
  assert.equal(r.confirmCount, 1); // só o "x" conta
  assert.equal(r.status, "pending");
});

test("confirma ao atingir o limiar", () => {
  const r = aggregateVotes(
    [{ id: "a", vote: "confirm" }, { id: "b", vote: "confirm" }],
    author,
  );
  assert.equal(r.confirmCount, CONFIRM_THRESHOLD);
  assert.equal(r.status, "confirmed");
});

test("conta UIDs distintos — voto repetido do mesmo uid não infla", () => {
  // (o id do doc garante 1 por uid; o Set é defesa extra)
  const r = aggregateVotes(
    [{ id: "a", vote: "confirm" }, { id: "a", vote: "confirm" }],
    author,
  );
  assert.equal(r.confirmCount, 1);
  assert.equal(r.status, "pending");
});

test("rejeita quando contestações passam o limiar e superam confirmações", () => {
  const r = aggregateVotes(
    [
      { id: "a", vote: "contest" },
      { id: "b", vote: "contest" },
      { id: "c", vote: "confirm" },
    ],
    author,
  );
  assert.equal(r.contestCount, 2);
  assert.equal(r.confirmCount, 1);
  assert.equal(r.status, "rejected");
});

test("empate confirm==contest no limiar resolve a favor de confirmado", () => {
  const r = aggregateVotes(
    [
      { id: "a", vote: "confirm" },
      { id: "b", vote: "confirm" },
      { id: "c", vote: "contest" },
      { id: "d", vote: "contest" },
    ],
    author,
  );
  assert.equal(r.status, "confirmed"); // confirm >= contest desempata
});

test("votos malformados são ignorados", () => {
  const r = aggregateVotes(
    [null, { vote: "confirm" }, { id: "a", vote: "xpto" }, { id: "b", vote: "confirm" }],
    author,
  );
  assert.equal(r.confirmCount, 1);
});

test("buildPromotedOccurrence monta doc com source e geocode de GPS", () => {
  const createdAt = new Date("2026-05-25T10:00:00.000Z");
  const occ = buildPromotedOccurrence(
    {
      lat: -12.97,
      lng: -38.5,
      type: "tiroteio",
      city: "Salvador",
      neighborhood: "Pirajá",
      confirmCount: 2,
      createdAt: { toDate: () => createdAt },
    },
    "rep123",
  );
  assert.equal(occ.source, "user_report");
  assert.equal(occ.geocodeMethod, "user_gps");
  assert.equal(occ.mainReason, "Tiroteio");
  assert.equal(occ.state, "Bahia");
  assert.equal(occ.reportId, "rep123");
  assert.equal(occ.latitude, -12.97);
  assert.equal(typeof occ.geohash, "string");
  assert.ok(occ.geohash.length === 8);
});

test("buildPromotedOccurrence dá TTL maior que a data de criação", () => {
  const createdAt = new Date("2026-05-25T10:00:00.000Z");
  const occ = buildPromotedOccurrence(
    { lat: -12.9, lng: -38.4, type: "roubo", createdAt: { toDate: () => createdAt } },
    "r",
  );
  assert.ok(occ.expiresAt.toDate().getTime() > createdAt.getTime());
  assert.equal(occ.neighborhood, null);
});

test("buildPromotedOccurrence usa o peso passado (reputação) ou o default", () => {
  const base = { lat: -12.9, lng: -38.4, type: "roubo" };
  const padrao = buildPromotedOccurrence(base, "r");
  assert.equal(padrao.weight, _internal.PROMOTED_WEIGHT);
  const comReputacao = buildPromotedOccurrence(base, "r", { weight: 0.58 });
  assert.equal(comReputacao.weight, 0.58);
});
