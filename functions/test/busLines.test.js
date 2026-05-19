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

  // ── Formato (A) — códigos numéricos ──────────────────────────────────

  it("aceita códigos numéricos simples", () => {
    assert.deepEqual(sanitizeBusLines(["1234"]), ["1234"]);
    assert.deepEqual(sanitizeBusLines(["1234", "5678"]), ["1234", "5678"]);
  });

  it("aceita códigos com letras/hífens (L-105, 0220-01)", () => {
    assert.deepEqual(sanitizeBusLines(["L-105"]), ["L-105"]);
    assert.deepEqual(sanitizeBusLines(["0220-01"]), ["0220-01"]);
  });

  it("normaliza códigos pra UPPERCASE", () => {
    assert.deepEqual(sanitizeBusLines(["l-105"]), ["L-105"]);
  });

  // ── Formato (B) — origem-destino ─────────────────────────────────────

  it("aceita linhas nomeadas com hífen (Cajazeiras-Lapa)", () => {
    assert.deepEqual(sanitizeBusLines(["Cajazeiras-Lapa"]), ["Cajazeiras-Lapa"]);
  });

  it("aceita linhas nomeadas com barra (Pituba/Rodoviária)", () => {
    assert.deepEqual(
      sanitizeBusLines(["Pituba/Rodoviária"]),
      ["Pituba/Rodoviária"],
    );
  });

  it("aceita linhas nomeadas com acentos e espaços (Itinga / Praça da Sé)", () => {
    assert.deepEqual(
      sanitizeBusLines(["Itinga / Praça da Sé"]),
      ["Itinga / Praça da Sé"],
    );
  });

  it("normaliza espaços duplos em linhas nomeadas", () => {
    assert.deepEqual(
      sanitizeBusLines(["Cajazeiras  -  Lapa"]),
      ["Cajazeiras - Lapa"],
    );
  });

  it("mantém o case original em linhas nomeadas (não força UPPER)", () => {
    assert.deepEqual(
      sanitizeBusLines(["Cajazeiras-Lapa"]),
      ["Cajazeiras-Lapa"],
    );
    // Mas dedup é case-insensitive
    assert.deepEqual(
      sanitizeBusLines(["Cajazeiras-Lapa", "cajazeiras-lapa"]),
      ["Cajazeiras-Lapa"],
    );
  });

  // ── Rejeições ────────────────────────────────────────────────────────

  it("rejeita strings sem dígito e sem separador (palavra única)", () => {
    assert.deepEqual(sanitizeBusLines(["ônibus para Lauro"]), []);
    assert.deepEqual(sanitizeBusLines(["linha amarela"]), []);
    assert.deepEqual(sanitizeBusLines(["Pituba"]), []); // só um nome
    assert.deepEqual(sanitizeBusLines(["ABCD"]), []);
  });

  it("rejeita strings com tokens curtos demais", () => {
    // "Sé" tem só 2 letras — sozinho não vale; o teste de Itinga/Praça da Sé
    // passa porque "Sé" faz parte de "Praça da Sé" (token de 9 chars).
    assert.deepEqual(sanitizeBusLines(["A-B"]), []);
    assert.deepEqual(sanitizeBusLines(["Lapa-Sé"]), []);
  });

  it("rejeita strings com mais de 40 chars", () => {
    assert.deepEqual(
      sanitizeBusLines(["1234 - Estação Lapa - Cajazeiras Salvador Centro"]),
      [],
    );
  });

  it("rejeita strings mistas com caracteres especiais (parênteses, vírgulas)", () => {
    assert.deepEqual(sanitizeBusLines(["1234 (ALTERNATIVO)"]), []);
    assert.deepEqual(sanitizeBusLines(["linha 1234, sentido Lapa"]), []);
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
