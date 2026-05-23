"use strict";

const { test } = require("node:test");
const assert = require("node:assert/strict");

const { _internal } = require("../lib/narrativeAggregator");
const {
  clusterItems,
  cosineSimilarity,
  editorialHeadline,
  narrativeId,
} = _internal;

function vec(seed, dim = 16) {
  // Geração determinística pra fixtures — vetores semelhantes têm seeds
  // próximos, vetores diferentes têm seeds longe.
  const v = new Array(dim);
  for (let i = 0; i < dim; i++) {
    v[i] = Math.sin(seed + i * 0.1);
  }
  return v;
}

test("cosineSimilarity 1 pra vetores idênticos", () => {
  const a = vec(1.0);
  assert.equal(cosineSimilarity(a, a), 1);
});

test("cosineSimilarity próxima de 1 pra vetores parecidos", () => {
  const sim = cosineSimilarity(vec(1.0), vec(1.01));
  assert.ok(sim > 0.99, `esperava > 0.99, veio ${sim}`);
});

test("cosineSimilarity baixa pra vetores muito diferentes", () => {
  const sim = cosineSimilarity(vec(0), vec(5));
  assert.ok(sim < 0.95, `esperava < 0.95, veio ${sim}`);
});

test("clusterItems agrupa relatos similares na mesma cidade", () => {
  const items = [
    { id: "a", city: "Salvador", neighborhood: "Pirajá", mainReason: "Tiroteio", date: new Date(), embedding: vec(1.0) },
    { id: "b", city: "Salvador", neighborhood: "Pirajá", mainReason: "Tiroteio", date: new Date(), embedding: vec(1.01) },
    { id: "c", city: "Salvador", neighborhood: "Pirajá", mainReason: "Tiroteio", date: new Date(), embedding: vec(1.02) },
  ];
  const clusters = clusterItems(items, {
    similarityThreshold: 0.8,
    minSize: 3,
  });
  assert.equal(clusters.length, 1);
  assert.equal(clusters[0].items.length, 3);
});

test("clusterItems não agrupa cidades diferentes", () => {
  const items = [
    { id: "a", city: "Salvador", neighborhood: "Pirajá", mainReason: "Tiroteio", date: new Date(), embedding: vec(1.0) },
    { id: "b", city: "Camaçari", neighborhood: "Centro", mainReason: "Tiroteio", date: new Date(), embedding: vec(1.0) },
    { id: "c", city: "Camaçari", neighborhood: "Centro", mainReason: "Tiroteio", date: new Date(), embedding: vec(1.0) },
    { id: "d", city: "Camaçari", neighborhood: "Centro", mainReason: "Tiroteio", date: new Date(), embedding: vec(1.0) },
  ];
  const clusters = clusterItems(items, {
    similarityThreshold: 0.8,
    minSize: 3,
  });
  // Salvador tem só 1 item (descartado por minSize), Camaçari tem 3 (passa).
  assert.equal(clusters.length, 1);
  assert.equal(clusters[0].city, "Camaçari");
});

test("clusterItems descarta clusters abaixo de minSize", () => {
  const items = [
    { id: "a", city: "Salvador", neighborhood: "X", mainReason: "Roubo", date: new Date(), embedding: vec(1.0) },
    { id: "b", city: "Salvador", neighborhood: "X", mainReason: "Roubo", date: new Date(), embedding: vec(1.01) },
  ];
  const clusters = clusterItems(items, {
    similarityThreshold: 0.8,
    minSize: 3,
  });
  assert.equal(clusters.length, 0);
});

test("editorialHeadline cita motivo dominante quando >= 60%", () => {
  const cluster = {
    city: "Salvador",
    items: new Array(5).fill(null),
  };
  const headline = editorialHeadline(
    cluster,
    ["Pirajá"],
    [{ reason: "Tiroteio", count: 4 }, { reason: "Roubo", count: 1 }],
  );
  assert.match(headline, /5 relatos relacionados a tiroteio em Pirajá/i);
});

test("editorialHeadline omite motivo quando não há dominante", () => {
  const cluster = {
    city: "Salvador",
    items: new Array(5).fill(null),
  };
  const headline = editorialHeadline(
    cluster,
    ["Pirajá", "Sussuarana"],
    [{ reason: "Tiroteio", count: 2 }, { reason: "Roubo", count: 2 }, { reason: "Outros", count: 1 }],
  );
  assert.match(headline, /5 relatos relacionados em região de Pirajá e Sussuarana/i);
  assert.doesNotMatch(headline, /tiroteio/i);
});

test("editorialHeadline nunca contém palavras alarmistas", () => {
  const cluster = { city: "Salvador", items: new Array(10).fill(null) };
  const headline = editorialHeadline(
    cluster,
    ["Pirajá"],
    [{ reason: "Tiroteio", count: 9 }],
  );
  const banned = ["PERIGO", "PERIGOSA", "CUIDADO", "EVITE", "URGENTE"];
  for (const word of banned) {
    assert.doesNotMatch(headline, new RegExp(word, "i"), `headline contém "${word}"`);
  }
});

test("narrativeId é determinístico e sluga acentos", () => {
  const id = narrativeId({
    city: "Salvador",
    neighborhoods: new Set(["Pirajá", "São Caetano"]),
  });
  assert.equal(id, "salvador__piraja-sao-caetano");
});

test("narrativeId estável independente da ordem dos bairros", () => {
  const a = narrativeId({
    city: "Salvador",
    neighborhoods: new Set(["A", "B"]),
  });
  const b = narrativeId({
    city: "Salvador",
    neighborhoods: new Set(["B", "A"]),
  });
  assert.equal(a, b);
});
