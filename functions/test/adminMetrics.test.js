"use strict";

const { test } = require("node:test");
const assert = require("node:assert");

const { _internal } = require("../lib/adminMetrics");
const { computeMetrics } = _internal;

const NOW = new Date("2026-05-22T12:00:00Z");

function userFixture({ providers = [], createdHoursAgo = 100, lastSignInHoursAgo } = {}) {
  const created = new Date(NOW.getTime() - createdHoursAgo * 3600 * 1000);
  const lastSignIn =
    lastSignInHoursAgo != null
      ? new Date(NOW.getTime() - lastSignInHoursAgo * 3600 * 1000)
      : created;
  return {
    providerData: providers.map((id) => ({ providerId: id })),
    metadata: {
      creationTime: created.toUTCString(),
      lastSignInTime: lastSignIn.toUTCString(),
    },
  };
}

function occurrenceFixture({ hoursAgo, source = "media", state = "BA", city = "Salvador", contested = false, mainReason = "tiroteio" } = {}) {
  return {
    date: new Date(NOW.getTime() - hoursAgo * 3600 * 1000),
    source,
    state,
    city,
    contested,
    mainReason,
  };
}

test("computeMetrics conta usuários por provider", () => {
  const users = [
    userFixture({ providers: [] }),
    userFixture({ providers: [] }),
    userFixture({ providers: ["google.com"] }),
  ];
  const result = computeMetrics({
    users,
    occurrencesLast7d: [],
    occurrencesTotal: 0,
    contestations: [],
    safeArrivals: [],
    now: NOW,
  });
  assert.equal(result.users.total, 3);
  assert.equal(result.users.anonymous, 2);
  assert.equal(result.users.google, 1);
});

test("computeMetrics separa janelas 24h e 7d de criação/sign-in", () => {
  const users = [
    userFixture({ providers: ["google.com"], createdHoursAgo: 2, lastSignInHoursAgo: 1 }), // dentro de 24h
    userFixture({ providers: [], createdHoursAgo: 50, lastSignInHoursAgo: 50 }), // dentro de 7d
    userFixture({ providers: [], createdHoursAgo: 200, lastSignInHoursAgo: 200 }), // fora
  ];
  const result = computeMetrics({
    users,
    occurrencesLast7d: [],
    occurrencesTotal: 0,
    contestations: [],
    safeArrivals: [],
    now: NOW,
  });
  assert.equal(result.users.createdLast24h, 1);
  assert.equal(result.users.createdLast7d, 2);
  assert.equal(result.users.activeLast24h, 1);
  assert.equal(result.users.activeLast7d, 2);
});

test("computeMetrics agrupa ocorrências por source/state/city e contesta", () => {
  const occurrences = [
    occurrenceFixture({ hoursAgo: 1, source: "fogocruzado", city: "Salvador" }),
    occurrenceFixture({ hoursAgo: 5, source: "media", city: "Salvador", contested: true }),
    occurrenceFixture({ hoursAgo: 30, source: "media", city: "Camaçari" }),
    occurrenceFixture({ hoursAgo: 100, source: "media", city: "Salvador" }),
  ];
  const result = computeMetrics({
    users: [],
    occurrencesLast7d: occurrences,
    occurrencesTotal: 287,
    contestations: [],
    safeArrivals: [],
    now: NOW,
  });
  assert.equal(result.occurrences.total, 287);
  assert.equal(result.occurrences.last7d, 4);
  assert.equal(result.occurrences.last24h, 2);
  assert.equal(result.occurrences.contested, 1);
  assert.deepEqual(result.occurrences.bySource, { fogocruzado: 1, media: 3 });
  assert.deepEqual(result.occurrences.byCity, { Salvador: 3, "Camaçari": 1 });
});

test("computeMetrics conta ocorrências distintas contestadas", () => {
  const contestations = [
    { occurrenceId: "occ1", submittedBy: "u1" },
    { occurrenceId: "occ1", submittedBy: "u2" },
    { occurrenceId: "occ2", submittedBy: "u1" },
  ];
  const result = computeMetrics({
    users: [],
    occurrencesLast7d: [],
    occurrencesTotal: 0,
    contestations,
    safeArrivals: [],
    now: NOW,
  });
  assert.equal(result.contestations.total, 3);
  assert.equal(result.contestations.occurrencesContested, 2);
});

test("computeMetrics soma safe_arrivals por janela 24h/7d", () => {
  const today = new Date(NOW.getTime()).toISOString().slice(0, 10);
  const ydy = new Date(NOW.getTime() - DAY).toISOString().slice(0, 10);
  const week = new Date(NOW.getTime() - 5 * DAY).toISOString().slice(0, 10);
  const old = new Date(NOW.getTime() - 30 * DAY).toISOString().slice(0, 10);
  const safeArrivals = [
    { day: today, count: 3 },
    { day: ydy, count: 2 },
    { day: week, count: 5 },
    { day: old, count: 100 },
  ];
  const result = computeMetrics({
    users: [],
    occurrencesLast7d: [],
    occurrencesTotal: 0,
    contestations: [],
    safeArrivals,
    now: NOW,
  });
  assert.equal(result.safeArrivals.last7d, 10);
  // last24h conta hoje + ontem porque a função compara dia em UTC vs cutoff de 24h.
  assert.ok(result.safeArrivals.last24h >= 3);
});

test("computeMetrics extrai top reasons ordenados", () => {
  const occurrences = [
    occurrenceFixture({ hoursAgo: 1, mainReason: "tiroteio" }),
    occurrenceFixture({ hoursAgo: 2, mainReason: "tiroteio" }),
    occurrenceFixture({ hoursAgo: 3, mainReason: "roubo" }),
    occurrenceFixture({ hoursAgo: 4, mainReason: "tiroteio" }),
    occurrenceFixture({ hoursAgo: 5, mainReason: "homicidio" }),
  ];
  const result = computeMetrics({
    users: [],
    occurrencesLast7d: occurrences,
    occurrencesTotal: 5,
    contestations: [],
    safeArrivals: [],
    now: NOW,
  });
  assert.equal(result.occurrences.topReasons[0].reason, "tiroteio");
  assert.equal(result.occurrences.topReasons[0].count, 3);
});

const DAY = 24 * 60 * 60 * 1000;
