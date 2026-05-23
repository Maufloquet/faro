"use strict";

const { describe, it } = require("node:test");
const assert = require("node:assert/strict");

const {
  resolveCityKey,
  isCoveredCity,
  stateForCity,
  COVERED_CITY_KEYS,
} = require("../lib/cityCentroids");

describe("resolveCityKey — match por palavra inteira (fix 2026-05-23)", () => {
  it("resolve nomes canônicos das 4 cidades RMS", () => {
    assert.equal(resolveCityKey("Salvador"), "salvador");
    assert.equal(resolveCityKey("Camaçari"), "camacari");
    assert.equal(resolveCityKey("Lauro de Freitas"), "lauro_de_freitas");
    assert.equal(resolveCityKey("Simões Filho"), "simoes_filho");
  });

  it("tolera variação de case e acentos", () => {
    assert.equal(resolveCityKey("salvador"), "salvador");
    assert.equal(resolveCityKey("camacari"), "camacari");
    assert.equal(resolveCityKey("CAMAÇARI"), "camacari");
  });

  it("aceita nome com fronteira de pontuação", () => {
    assert.equal(resolveCityKey("Salvador, BA"), "salvador");
    assert.equal(resolveCityKey("(Camaçari)"), "camacari");
  });

  it("NÃO casa alias como prefixo/sufixo de palavra maior", () => {
    // REGRESSÃO: antes do fix, `q.includes(alias)` casava substring
    // crua — "salvadora" engolia o alias "salvador". Regex com
    // fronteira de palavra rejeita.
    assert.equal(resolveCityKey("Salvadora Maria"), null);
    assert.equal(resolveCityKey("Recifense"), null);
  });

  it("retorna null pra cidades fora dos centroids", () => {
    assert.equal(resolveCityKey("Feira de Santana"), null);
    assert.equal(resolveCityKey("Itabuna"), null);
    assert.equal(resolveCityKey("Maceió"), null);
  });

  it("retorna null pra input vazio/null", () => {
    assert.equal(resolveCityKey(null), null);
    assert.equal(resolveCityKey(""), null);
    assert.equal(resolveCityKey("   "), null);
  });
});

describe("isCoveredCity — whitelist de ingestão", () => {
  it("aceita as 4 cidades RMS cobertas pela Camada 2", () => {
    for (const key of ["salvador", "camacari", "lauro_de_freitas", "simoes_filho"]) {
      assert.equal(isCoveredCity(key), true, `${key} deveria ser coberta`);
    }
  });

  it("rejeita capitais não-baianas mesmo presentes em centroids", () => {
    // CITY_CENTROIDS mantém RJ/PE/SP pra futuras expansões, mas a
    // whitelist bloqueia ingestão hoje.
    for (const key of ["rio_de_janeiro", "recife", "sao_paulo", "niteroi"]) {
      assert.equal(isCoveredCity(key), false, `${key} NÃO deveria ser coberta`);
    }
  });

  it("rejeita key inválida", () => {
    assert.equal(isCoveredCity(null), false);
    assert.equal(isCoveredCity("desconhecida"), false);
  });

  it("COVERED_CITY_KEYS tem exatamente 4 entradas", () => {
    assert.equal(COVERED_CITY_KEYS.size, 4);
  });
});

describe("stateForCity", () => {
  it("BA pra as 4 cidades cobertas", () => {
    for (const key of ["salvador", "camacari", "lauro_de_freitas", "simoes_filho"]) {
      assert.equal(stateForCity(key), "BA");
    }
  });

  it("retorna null pra key desconhecida (não mais 'BA' por default)", () => {
    assert.equal(stateForCity("xpto"), null);
    assert.equal(stateForCity(null), null);
  });
});
