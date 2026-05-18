"use strict";

const { describe, it } = require("node:test");
const assert = require("node:assert/strict");

const { _internal } = require("../lib/newsIngest");
const { sanitizeBusLines, sanitizeTransportContext } = _internal;

describe("newsIngest.sanitizeBusLines", () => {
  it("retorna [] pra entrada não-array", () => {
    assert.deepEqual(sanitizeBusLines(null), []);
    assert.deepEqual(sanitizeBusLines(undefined), []);
    assert.deepEqual(sanitizeBusLines("1234"), []);
    assert.deepEqual(sanitizeBusLines({}), []);
  });

  it("aceita códigos numéricos simples", () => {
    assert.deepEqual(sanitizeBusLines(["1234"]), ["1234"]);
    assert.deepEqual(sanitizeBusLines(["1234", "5678"]), ["1234", "5678"]);
  });

  it("aceita códigos com letras/hífens (L-105, 0220-01)", () => {
    assert.deepEqual(sanitizeBusLines(["L-105"]), ["L-105"]);
    assert.deepEqual(sanitizeBusLines(["0220-01"]), ["0220-01"]);
  });

  it("descarta strings sem dígito (defesa contra IA alucinar descrição)", () => {
    assert.deepEqual(sanitizeBusLines(["ônibus para Lauro"]), []);
    assert.deepEqual(sanitizeBusLines(["linha amarela"]), []);
    assert.deepEqual(sanitizeBusLines(["ABCD"]), []);
  });

  it("descarta strings muito longas (defesa contra IA gerar nome de empresa)", () => {
    assert.deepEqual(sanitizeBusLines(["1234 - Estação Lapa - Cajazeiras Salvador"]), []);
  });

  it("descarta strings com caracteres especiais (acentos, parênteses, vírgulas)", () => {
    assert.deepEqual(sanitizeBusLines(["1234 (ALTERNATIVO)"]), []);
    assert.deepEqual(sanitizeBusLines(["linha 1234, sentido Lapa"]), []);
  });

  it("normaliza pra UPPERCASE e deduplica", () => {
    assert.deepEqual(sanitizeBusLines(["l-105", "L-105", "l-105"]), ["L-105"]);
  });

  it("ignora entradas não-string no array", () => {
    assert.deepEqual(sanitizeBusLines([1234, null, "1234", undefined]), ["1234"]);
  });
});

describe("newsIngest.sanitizeTransportContext", () => {
  it("aceita só 'onibus' ou 'metro'", () => {
    assert.equal(sanitizeTransportContext("onibus"), "onibus");
    assert.equal(sanitizeTransportContext("metro"), "metro");
  });

  it("rejeita qualquer outro valor (defesa contra IA inventar 'BRT', 'taxi', etc.)", () => {
    assert.equal(sanitizeTransportContext("brt"), null);
    assert.equal(sanitizeTransportContext("ônibus"), null);
    assert.equal(sanitizeTransportContext("ÔNIBUS"), null);
    assert.equal(sanitizeTransportContext(null), null);
    assert.equal(sanitizeTransportContext(undefined), null);
  });
});
