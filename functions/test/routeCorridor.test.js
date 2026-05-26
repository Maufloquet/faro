"use strict";

const { test } = require("node:test");
const assert = require("node:assert/strict");

const {
  haversineKm,
  distanceToSegmentKm,
  pointInCorridor,
} = require("../lib/routeCorridor");

// Salvador ~ (-12.97, -38.50). Segmento curto pra testar.
const aLat = -12.97, aLng = -38.50;
const bLat = -12.95, bLng = -38.48;

test("haversineKm bate com distância conhecida (aprox)", () => {
  // ~1.11 km por 0.01° de latitude
  const d = haversineKm(-12.97, -38.5, -12.96, -38.5);
  assert.ok(Math.abs(d - 1.113) < 0.05, `d=${d}`);
});

test("ponto sobre o segmento tem distância ~0", () => {
  const midLat = (aLat + bLat) / 2;
  const midLng = (aLng + bLng) / 2;
  const d = distanceToSegmentKm(midLat, midLng, aLat, aLng, bLat, bLng);
  assert.ok(d < 0.05, `d=${d}`);
});

test("projeção fora do segmento usa o endpoint mais próximo", () => {
  // ponto bem antes de A, na direção oposta a B
  const d = distanceToSegmentKm(-12.99, -38.52, aLat, aLng, bLat, bLng);
  const dEndpoint = haversineKm(-12.99, -38.52, aLat, aLng);
  assert.ok(Math.abs(d - dEndpoint) < 0.001, `d=${d} endpoint=${dEndpoint}`);
});

test("segmento degenerado (a==b) cai pra ponto-ponto", () => {
  const d = distanceToSegmentKm(-12.96, -38.50, aLat, aLng, aLat, aLng);
  const dp = haversineKm(-12.96, -38.50, aLat, aLng);
  assert.ok(Math.abs(d - dp) < 0.001);
});

test("pointInCorridor: ponto no meio entra com buffer pequeno", () => {
  const midLat = (aLat + bLat) / 2;
  const midLng = (aLng + bLng) / 2;
  assert.equal(
    pointInCorridor(midLat, midLng, aLat, aLng, bLat, bLng, 0.5),
    true,
  );
});

test("pointInCorridor: ponto longe fica fora (fast-path bbox)", () => {
  assert.equal(
    pointInCorridor(-13.30, -38.90, aLat, aLng, bLat, bLng, 0.5),
    false,
  );
});

test("pointInCorridor: buffer maior captura ponto a ~400m do segmento", () => {
  // desloca o ponto médio ~0.004° em lng (~0.43 km nessa latitude)
  const midLat = (aLat + bLat) / 2;
  const midLng = (aLng + bLng) / 2 + 0.004;
  assert.equal(pointInCorridor(midLat, midLng, aLat, aLng, bLat, bLng, 0.2), false);
  assert.equal(pointInCorridor(midLat, midLng, aLat, aLng, bLat, bLng, 0.6), true);
});
