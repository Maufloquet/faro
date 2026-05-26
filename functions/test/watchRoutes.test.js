"use strict";

const { test } = require("node:test");
const assert = require("node:assert/strict");

const { _internal } = require("../lib/watchRoutes");
const { newOccurrencesForRoute, buildRouteAlertText } = _internal;

const route = {
  originLat: -12.97,
  originLng: -38.50,
  destLat: -12.95,
  destLng: -38.48,
  corridorMeters: 500,
  lastCheckedMs: 1000,
};

const onCorridor = { latitude: -12.96, longitude: -38.49, dateMs: 5000 };
const farAway = { latitude: -13.30, longitude: -38.90, dateMs: 5000 };
const old = { latitude: -12.96, longitude: -38.49, dateMs: 500 }; // antes do lastChecked

test("pega só ocorrências novas e dentro do corredor", () => {
  const hits = newOccurrencesForRoute([onCorridor, farAway, old], route);
  assert.equal(hits.length, 1);
  assert.equal(hits[0], onCorridor);
});

test("ocorrência anterior ao lastChecked é ignorada", () => {
  const hits = newOccurrencesForRoute([old], route);
  assert.equal(hits.length, 0);
});

test("ocorrência fora do corredor é ignorada mesmo se nova", () => {
  const hits = newOccurrencesForRoute([farAway], route);
  assert.equal(hits.length, 0);
});

test("corredor default 500m quando corridorMeters ausente", () => {
  const r = { ...route, corridorMeters: undefined };
  const hits = newOccurrencesForRoute([onCorridor], r);
  assert.equal(hits.length, 1);
});

test("buildRouteAlertText: singular, plural e rótulo", () => {
  assert.match(buildRouteAlertText("Casa → Trabalho", 1), /1 relato novo no trajeto Casa → Trabalho/);
  assert.match(buildRouteAlertText("Casa → Trabalho", 3), /3 relatos novos/);
  assert.match(buildRouteAlertText("", 2), /no seu trajeto/);
});

test("buildRouteAlertText satura em 9+ e nunca é alarmista", () => {
  const t = buildRouteAlertText("X", 25);
  assert.match(t, /9\+ relatos novos/);
  for (const w of ["PERIGO", "CUIDADO", "EVITE", "URGENTE"]) {
    assert.doesNotMatch(t.toUpperCase(), new RegExp(w));
  }
});
