"use strict";

const { describe, it } = require("node:test");
const assert = require("node:assert/strict");

const { _internal } = require("../lib/osmFetch");
const { parseBusStops } = _internal;

const sampleResponse = {
  version: 0.6,
  generator: "Overpass API",
  elements: [
    {
      type: "node",
      id: 1001,
      lat: -12.9714,
      lon: -38.5014,
      tags: {
        highway: "bus_stop",
        name: "Praça da Sé",
        shelter: "yes",
        bench: "yes",
        lit: "yes",
      },
    },
    {
      type: "node",
      id: 1002,
      lat: -12.8895,
      lon: -38.3260,
      tags: {
        highway: "bus_stop",
      },
    },
    // Mesmo node como platform — deve ser ignorado (dedup por id).
    {
      type: "node",
      id: 1001,
      lat: -12.9714,
      lon: -38.5014,
      tags: {
        public_transport: "platform",
        bus: "yes",
      },
    },
    // Way não deve aparecer (só nodes interessam).
    {
      type: "way",
      id: 2001,
      nodes: [1001, 1002],
    },
    // Sem lat/lng → descarta.
    {
      type: "node",
      id: 1003,
      tags: { highway: "bus_stop" },
    },
  ],
};

describe("osmFetch.parseBusStops", () => {
  it("retorna lista vazia pra resposta inválida", () => {
    assert.deepEqual(parseBusStops(null), []);
    assert.deepEqual(parseBusStops({}), []);
    assert.deepEqual(parseBusStops({ elements: "not-an-array" }), []);
  });

  it("extrai pontos com lat/lng numéricos", () => {
    const stops = parseBusStops(sampleResponse);
    assert.equal(stops.length, 2);
    assert.equal(stops[0].id, 1001);
    assert.equal(stops[1].id, 1002);
  });

  it("deduplica por id (mesmo node como bus_stop E platform)", () => {
    const stops = parseBusStops(sampleResponse);
    const ids = stops.map((s) => s.id);
    assert.equal(new Set(ids).size, ids.length, "ids devem ser únicos");
  });

  it("descarta elementos que não são node", () => {
    const stops = parseBusStops(sampleResponse);
    assert.ok(!stops.some((s) => s.id === 2001));
  });

  it("descarta nodes sem lat/lng", () => {
    const stops = parseBusStops(sampleResponse);
    assert.ok(!stops.some((s) => s.id === 1003));
  });

  it("preserva tags relevantes (name, shelter, bench, lit)", () => {
    const stops = parseBusStops(sampleResponse);
    const praca = stops.find((s) => s.id === 1001);
    assert.equal(praca.name, "Praça da Sé");
    assert.equal(praca.shelter, true);
    assert.equal(praca.bench, true);
    assert.equal(praca.lit, true);
  });

  it("trata tags ausentes como null/false (não confundir 'desconhecido' com 'não')", () => {
    const stops = parseBusStops(sampleResponse);
    const semNome = stops.find((s) => s.id === 1002);
    assert.equal(semNome.name, null);
    assert.equal(semNome.shelter, false);
    assert.equal(semNome.bench, false);
    assert.equal(semNome.lit, false);
  });

  it("arredonda coords pra 5 casas (suficiente pra ~1m de precisão)", () => {
    const stops = parseBusStops({
      elements: [
        {
          type: "node",
          id: 9999,
          lat: -12.97141234567,
          lon: -38.50145678901,
          tags: { highway: "bus_stop" },
        },
      ],
    });
    assert.equal(stops[0].lat, -12.97141);
    assert.equal(stops[0].lng, -38.50146);
  });
});
