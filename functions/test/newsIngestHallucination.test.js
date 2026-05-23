"use strict";

const { describe, it } = require("node:test");
const assert = require("node:assert/strict");

const { _internal } = require("../lib/newsIngest");
const {
  normalizeForMatch,
  cityAppearsInText,
  neighborhoodAppearsInText,
} = _internal;

describe("newsIngest anti-hallucination — normalizeForMatch", () => {
  it("remove acento + lowercase + colapsa espaços", () => {
    assert.equal(
      normalizeForMatch("São   Bernardo   do Campo"),
      "sao bernardo do campo",
    );
  });

  it("retorna string vazia pra null/undefined", () => {
    assert.equal(normalizeForMatch(null), "");
    assert.equal(normalizeForMatch(undefined), "");
    assert.equal(normalizeForMatch(""), "");
  });
});

describe("cityAppearsInText", () => {
  it("encontra cidade mencionada como palavra inteira", () => {
    const text = normalizeForMatch("Tiroteio em Salvador deixa feridos");
    assert.equal(cityAppearsInText("Salvador", text), true);
  });

  it("encontra com acento, case e pontuação variados", () => {
    const text = normalizeForMatch(
      "Operação em Camaçari, na Bahia, prende suspeitos.",
    );
    assert.equal(cityAppearsInText("Camaçari", text), true);
  });

  it("rejeita cidade que NÃO aparece no texto (alucinação do LLM)", () => {
    // Cenário real: matéria menciona "Feira de Santana" mas LLM
    // retorna "Salvador" por ter visto "Bahia" no texto.
    const text = normalizeForMatch(
      "Tiroteio em Feira de Santana deixa um morto na Bahia.",
    );
    assert.equal(cityAppearsInText("Salvador", text), false);
  });

  it("aceita match com fronteira de pontuação", () => {
    const text = normalizeForMatch("Crime em Lauro de Freitas.");
    assert.equal(cityAppearsInText("Lauro de Freitas", text), true);
  });

  it("rejeita match parcial dentro de outra palavra", () => {
    // "salvadores" (improvável mas teoricamente) não deve casar.
    const text = normalizeForMatch("Os salvadores chegaram cedo.");
    assert.equal(cityAppearsInText("Salvador", text), false);
  });
});

describe("neighborhoodAppearsInText", () => {
  it("encontra bairro mencionado", () => {
    const text = normalizeForMatch("Roubo no Pelourinho na madrugada");
    assert.equal(neighborhoodAppearsInText("Pelourinho", text), true);
  });

  it("rejeita bairro alucinado pelo LLM", () => {
    const text = normalizeForMatch("Tiroteio na Avenida ACM");
    assert.equal(neighborhoodAppearsInText("Pituba", text), false);
  });

  it("tolera nome de bairro com espaço (Nova Brasília)", () => {
    const text = normalizeForMatch("Crime em Nova Brasília, Salvador.");
    assert.equal(neighborhoodAppearsInText("Nova Brasília", text), true);
  });
});
