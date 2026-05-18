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

  it("bairro válido com cidade ausente ainda casa via fallback global", () => {
    const r = resolveBairro("Pirajá", null);
    assert.ok(r);
    assert.equal(r.cityKey, "salvador");
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
});
