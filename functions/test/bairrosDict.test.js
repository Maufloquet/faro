"use strict";

const { describe, it } = require("node:test");
const assert = require("node:assert/strict");

const { resolveBairro } = require("../lib/bairrosDict");

describe("bairrosDict.resolveBairro", () => {
  it("match exato é case + acento insensitive", () => {
    const a = resolveBairro("Pirajá", "Salvador");
    const b = resolveBairro("piraja", "salvador");
    assert.ok(a, "deveria resolver Pirajá");
    assert.equal(a.method, "exact");
    assert.equal(a.cityKey, "salvador");
    assert.deepEqual({ lat: b.lat, lng: b.lng }, { lat: a.lat, lng: a.lng });
  });

  it("retorna lat/lng numéricos finitos pra bairros conhecidos de Salvador", () => {
    for (const bairro of ["Pelourinho", "Barra", "Itapuã", "Pirajá", "Brotas"]) {
      const r = resolveBairro(bairro, "Salvador");
      assert.ok(r, `${bairro} deveria ter match`);
      assert.equal(typeof r.lat, "number");
      assert.equal(typeof r.lng, "number");
      assert.ok(Number.isFinite(r.lat) && Number.isFinite(r.lng));
    }
  });

  it("fuzzy match cobre erros tipográficos pequenos", () => {
    // "Brotras" → Brotas (distância 1)
    const r = resolveBairro("Brotras", "Salvador");
    assert.ok(r);
    assert.equal(r.method, "fuzzy");
  });

  it("erros grandes não casam (acima do threshold)", () => {
    const r = resolveBairro("Xyzabcde", "Salvador");
    // Não deve casar como fuzzy — cai pro centroide da cidade.
    assert.equal(r.method, "city-centroid");
  });

  it("sem bairro, cai pro centroide da cidade", () => {
    const r = resolveBairro(null, "Salvador");
    assert.ok(r);
    assert.equal(r.method, "city-centroid");
    assert.equal(r.matched, "Salvador");
  });

  it("cidade desconhecida sem bairro retorna null", () => {
    const r = resolveBairro(null, "Feira de Santana");
    assert.equal(r, null);
  });

  it("bairro válido com cidade ausente retorna null (sem fallback global)", () => {
    // REGRESSÃO 2026-05-23: o fallback inter-cidades vazava notícias do
    // interior baiano em Salvador. Agora, sem cidade resolvida, recusa.
    const r = resolveBairro("Pirajá", null);
    assert.equal(r, null);
  });

  it("query curta (<3 chars) não faz match de bairro, vai pro centroide", () => {
    const r = resolveBairro("ba", "Salvador");
    assert.equal(r.method, "city-centroid");
  });

  it("aceita aliases de cidade (sem acento)", () => {
    const r = resolveBairro(null, "camacari");
    assert.ok(r);
    assert.equal(r.cityKey, "camacari");
  });

  // ── Regressão: bugs documentados de geocoding ─────────────────────────

  it("'Lapinha de Cima' NÃO é engolida por Lapa (nome curto)", () => {
    // Antes da correção: query.includes('lapa') = true → match em Lapa.
    // Agora: Lapa tem 4 chars < SUBSTRING_MIN_LEN, substring não vale.
    // Cai pra fuzzy ou centroide — qualquer um é mais honesto que Lapa.
    const r = resolveBairro("Lapinha de Cima", "Salvador");
    assert.notEqual(r?.matched, "Lapa");
  });

  it("'Barra do Pojuca' em Camaçari NÃO mapeia pra Barra de Salvador", () => {
    // Camaçari não tem 'Barra do Pojuca' exato no dict. Antes da correção,
    // o fallback inter-cidades batia em 'Barra' (5 chars) de Salvador via
    // substring. Agora exactOnly bloqueia esse fallback ruidoso.
    const r = resolveBairro("Barra do Pojuca", "Camaçari");
    if (r) {
      // Se houver match, NÃO pode ser Barra de Salvador
      assert.notEqual(
        `${r.matched}|${r.cityKey}`,
        "Barra|salvador",
        "não pode resolver pra Barra de Salvador",
      );
    }
  });

  it("nome curto exato continua resolvendo (Barra, Lapa, Roma)", () => {
    // Match exato segue funcionando — só substring/fuzzy dele que limita.
    for (const nome of ["Barra", "Lapa", "Roma"]) {
      const r = resolveBairro(nome, "Salvador");
      assert.ok(r, `${nome} deveria resolver`);
      assert.equal(r.method, "exact");
    }
  });

  it("'Centro' sem cidade retorna null (colisão entre 4 cidades é ambiguidade)", () => {
    // REGRESSÃO 2026-05-23: "Centro" existe em Salvador, Camaçari, Lauro
    // e Simões. Antes o fallback inter-cidades batia em Salvador
    // (primeiro iterado), vazando notícias das outras 3 cidades em
    // Salvador. Agora qualquer ambiguidade sem cidade explícita recusa.
    const r = resolveBairro("Centro", null);
    assert.equal(r, null);
  });

  it("'Centro' com cidade Camaçari fica em Camaçari (não vaza pra Salvador)", () => {
    const r = resolveBairro("Centro", "Camaçari");
    assert.ok(r);
    assert.equal(r.cityKey, "camacari");
    assert.equal(r.matched, "Centro");
  });

  it("'Itinga' com cidade Lauro fica em Lauro, não em Salvador", () => {
    // Colisão real: Itinga existe nas duas. Cidade explícita decide.
    const r = resolveBairro("Itinga", "Lauro de Freitas");
    assert.ok(r);
    assert.equal(r.cityKey, "lauro_de_freitas");
  });

  it("'Itinga' com cidade Salvador fica em Salvador", () => {
    const r = resolveBairro("Itinga", "Salvador");
    assert.ok(r);
    assert.equal(r.cityKey, "salvador");
  });

  it("cidade fora das 4 cobertas retorna null (não chuta bairro)", () => {
    // Feira de Santana existe no CITY_CENTROIDS pra outras coisas, mas
    // não está coberta pela Camada 2 hoje.
    const r = resolveBairro("Centro", "Feira de Santana");
    assert.equal(r, null);
  });

  it("Rio de Janeiro (presente em centroids mas não coberta) retorna null", () => {
    // Centroids mantém RJ/PE/SP pra futuras expansões, mas a whitelist
    // bloqueia ingestão fora das 4 cidades BA.
    const r = resolveBairro(null, "Rio de Janeiro");
    assert.equal(r, null);
  });
});
