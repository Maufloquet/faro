"use strict";

const { describe, it } = require("node:test");
const assert = require("node:assert/strict");

const { _internal } = require("../lib/osmInfraIngest");
const { parseInfra, QUERIES } = _internal;

describe("osmInfraIngest.parseInfra", () => {
  it("retorna lista vazia pra resposta inválida", () => {
    assert.deepEqual(parseInfra(null, "police"), []);
    assert.deepEqual(parseInfra({}, "police"), []);
    assert.deepEqual(parseInfra({ elements: "x" }, "police"), []);
  });

  it("extrai node de delegacia com phone/operator", () => {
    const items = parseInfra(
      {
        elements: [
          {
            type: "node",
            id: 1,
            lat: -12.97,
            lon: -38.5,
            tags: {
              amenity: "police",
              name: "12ª DT",
              phone: "+5571999",
              operator: "PCBA",
            },
          },
        ],
      },
      "police",
    );
    assert.equal(items.length, 1);
    assert.equal(items[0].name, "12ª DT");
    assert.equal(items[0].phone, "+5571999");
    assert.equal(items[0].operator, "PCBA");
    assert.equal(items[0].type, "node");
  });

  it("extrai way usando o center retornado por 'out center'", () => {
    const items = parseInfra(
      {
        elements: [
          {
            type: "way",
            id: 99,
            center: { lat: -12.9, lon: -38.4 },
            tags: { amenity: "hospital", name: "Hospital X" },
          },
        ],
      },
      "hospitals",
    );
    assert.equal(items.length, 1);
    assert.equal(items[0].id, 99);
    assert.equal(items[0].type, "way");
    assert.equal(items[0].lat, -12.9);
    assert.equal(items[0].lng, -38.4);
  });

  it("hospitals: emergency=yes vira true; ausente fica undefined (não false)", () => {
    const items = parseInfra(
      {
        elements: [
          {
            type: "node",
            id: 1,
            lat: -12.9,
            lon: -38.4,
            tags: { amenity: "hospital", emergency: "yes", name: "ER" },
          },
          {
            type: "node",
            id: 2,
            lat: -12.91,
            lon: -38.41,
            tags: { amenity: "hospital", name: "Sem dado" },
          },
        ],
      },
      "hospitals",
    );
    assert.equal(items[0].emergency, true);
    assert.equal(items[1].emergency, undefined);
  });

  it("street_lamps: só guarda id e coords (sem tags extras)", () => {
    const items = parseInfra(
      {
        elements: [
          {
            type: "node",
            id: 7,
            lat: -12.95,
            lon: -38.45,
            tags: { highway: "street_lamp", lit: "yes" },
          },
        ],
      },
      "street_lamps",
    );
    assert.equal(items.length, 1);
    assert.equal(items[0].id, 7);
    assert.equal(items[0].name, null);
    assert.equal(items[0].shop, undefined);
  });

  it("commerce_24h: shop/amenity/brand preservados", () => {
    const items = parseInfra(
      {
        elements: [
          {
            type: "node",
            id: 1,
            lat: -12.9,
            lon: -38.4,
            tags: {
              shop: "convenience",
              opening_hours: "24/7",
              name: "Conveniência X",
              brand: "BR Mania",
            },
          },
          {
            type: "node",
            id: 2,
            lat: -12.91,
            lon: -38.41,
            tags: {
              amenity: "fuel",
              opening_hours: "24/7",
              name: "Posto Y",
            },
          },
        ],
      },
      "commerce_24h",
    );
    assert.equal(items[0].shop, "convenience");
    assert.equal(items[0].brand, "BR Mania");
    assert.equal(items[1].amenity, "fuel");
  });

  it("deduplica por type:id (way 1 e node 1 são distintos)", () => {
    const items = parseInfra(
      {
        elements: [
          { type: "node", id: 1, lat: -12.9, lon: -38.4, tags: {} },
          { type: "node", id: 1, lat: -12.9, lon: -38.4, tags: {} },
          {
            type: "way",
            id: 1,
            center: { lat: -12.91, lon: -38.41 },
            tags: {},
          },
        ],
      },
      "police",
    );
    assert.equal(items.length, 2);
  });

  it("descarta elementos sem coords resolúveis", () => {
    const items = parseInfra(
      {
        elements: [
          { type: "node", id: 1, tags: {} },
          { type: "way", id: 2, tags: {} },
          { type: "relation", id: 3, tags: {} },
        ],
      },
      "police",
    );
    assert.equal(items.length, 0);
  });

  it("arredonda coords pra 5 casas", () => {
    const items = parseInfra(
      {
        elements: [
          {
            type: "node",
            id: 1,
            lat: -12.97141234567,
            lon: -38.50145678901,
            tags: {},
          },
        ],
      },
      "police",
    );
    assert.equal(items[0].lat, -12.97141);
    assert.equal(items[0].lng, -38.50146);
  });

  it("QUERIES expõe as 4 categorias esperadas", () => {
    assert.deepEqual(
      Object.keys(QUERIES).sort(),
      ["commerce_24h", "hospitals", "police", "street_lamps"],
    );
  });
});
