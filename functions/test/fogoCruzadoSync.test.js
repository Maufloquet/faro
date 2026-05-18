"use strict";

const { describe, it } = require("node:test");
const assert = require("node:assert/strict");

const { _internal } = require("../lib/fogoCruzadoSync");
const { prepareOccurrenceDoc } = _internal;

const TTL_MS = 24 * 60 * 60 * 1000; // 1 dia

const sampleItem = {
  id: "abc-123",
  latitude: -12.97,
  longitude: -38.50,
  date: "2026-05-17T12:00:00.000Z",
  state: { name: "Bahia" },
  city: { name: "Salvador" },
  neighborhood: { name: "Pelourinho" },
  contextInfo: { mainReason: { name: "Tiroteio" } },
  policeAction: true,
  agentPresence: false,
  documentNumber: "BO-987",
};

describe("fogoCruzadoSync.prepareOccurrenceDoc", () => {
  it("retorna null quando latitude está faltando", () => {
    const r = prepareOccurrenceDoc({ ...sampleItem, latitude: null }, "BA", TTL_MS);
    assert.equal(r, null);
  });

  it("retorna null quando longitude está faltando", () => {
    const r = prepareOccurrenceDoc({ ...sampleItem, longitude: undefined }, "BA", TTL_MS);
    assert.equal(r, null);
  });

  it("retorna null para item nulo ou indefinido", () => {
    assert.equal(prepareOccurrenceDoc(null, "BA", TTL_MS), null);
    assert.equal(prepareOccurrenceDoc(undefined, "BA", TTL_MS), null);
  });

  it("mapeia campos básicos preservando o id como docId", () => {
    const r = prepareOccurrenceDoc(sampleItem, "BA", TTL_MS);
    assert.equal(r.docId, "abc-123");
    assert.equal(r.fields.externalId, "abc-123");
    assert.equal(r.fields.latitude, -12.97);
    assert.equal(r.fields.longitude, -38.50);
    assert.equal(r.fields.state, "Bahia");
    assert.equal(r.fields.city, "Salvador");
    assert.equal(r.fields.neighborhood, "Pelourinho");
    assert.equal(r.fields.mainReason, "Tiroteio");
    assert.equal(r.fields.policeAction, true);
    assert.equal(r.fields.agentPresence, false);
    assert.equal(r.fields.source, "fogo_cruzado");
    assert.equal(r.fields.weight, 0.7);
    assert.equal(r.fields.documentNumber, "BO-987");
  });

  it("calcula expiresAt = date + ttlMs", () => {
    const r = prepareOccurrenceDoc(sampleItem, "BA", TTL_MS);
    const delta = r.fields.expiresAt.getTime() - r.fields.date.getTime();
    assert.equal(delta, TTL_MS);
  });

  it("preserva date como Date (Timestamp é responsabilidade do caller)", () => {
    const r = prepareOccurrenceDoc(sampleItem, "BA", TTL_MS);
    assert.ok(r.fields.date instanceof Date);
    assert.ok(r.fields.expiresAt instanceof Date);
  });

  it("usa stateAbbr como fallback quando state.name está ausente", () => {
    const r = prepareOccurrenceDoc({ ...sampleItem, state: null }, "PE", TTL_MS);
    assert.equal(r.fields.state, "PE");
  });

  it("normaliza policeAction/agentPresence para boolean", () => {
    const r = prepareOccurrenceDoc(
      { ...sampleItem, policeAction: 1, agentPresence: 0 },
      "BA",
      TTL_MS,
    );
    assert.equal(r.fields.policeAction, true);
    assert.equal(r.fields.agentPresence, false);
  });

  it("geohash tem precisão 8", () => {
    const r = prepareOccurrenceDoc(sampleItem, "BA", TTL_MS);
    assert.equal(r.fields.geohash.length, 8);
  });

  it("documentNumber e demais campos opcionais viram null quando ausentes", () => {
    const r = prepareOccurrenceDoc(
      {
        id: "x",
        latitude: -12.97,
        longitude: -38.50,
        date: "2026-05-17T12:00:00Z",
      },
      "BA",
      TTL_MS,
    );
    assert.equal(r.fields.city, null);
    assert.equal(r.fields.neighborhood, null);
    assert.equal(r.fields.mainReason, null);
    assert.equal(r.fields.documentNumber, null);
  });

  it("popula eventKey com cidade + bairro + tipo normalizados", () => {
    const r = prepareOccurrenceDoc(sampleItem, "BA", TTL_MS);
    assert.equal(r.fields.eventKey, "salvador|pelourinho|tiroteio");
  });

  it("eventKey é null quando city ou mainReason ausentes (não dedupar lixo)", () => {
    const noCity = prepareOccurrenceDoc({ ...sampleItem, city: null }, "BA", TTL_MS);
    assert.equal(noCity.fields.eventKey, null);

    const noReason = prepareOccurrenceDoc(
      { ...sampleItem, contextInfo: null },
      "BA",
      TTL_MS,
    );
    assert.equal(noReason.fields.eventKey, null);
  });

  it("itens equivalentes (mesma cidade/bairro/tipo) geram a mesma eventKey", () => {
    const a = prepareOccurrenceDoc(sampleItem, "BA", TTL_MS);
    const b = prepareOccurrenceDoc(
      {
        ...sampleItem,
        id: "outro-id",
        city: { name: "salvador" },           // case diferente
        neighborhood: { name: "PELOURINHO" }, // case diferente
      },
      "BA",
      TTL_MS,
    );
    assert.equal(a.fields.eventKey, b.fields.eventKey);
  });
});
