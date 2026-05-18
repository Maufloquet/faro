"use strict";

const { describe, it } = require("node:test");
const assert = require("node:assert/strict");

const { buildEventKey } = require("../lib/eventKey");

describe("eventKey.buildEventKey", () => {
  it("retorna null quando city ausente", () => {
    assert.equal(buildEventKey({ city: null, neighborhood: "Pirajá", mainReason: "Tiroteio" }), null);
    assert.equal(buildEventKey({ city: "", mainReason: "Tiroteio" }), null);
    assert.equal(buildEventKey({}), null);
  });

  it("retorna null quando mainReason ausente", () => {
    assert.equal(buildEventKey({ city: "Salvador", neighborhood: "Pirajá", mainReason: null }), null);
    assert.equal(buildEventKey({ city: "Salvador", neighborhood: "Pirajá" }), null);
  });

  it("monta chave canônica com cidade + bairro + tipo normalizados", () => {
    const k = buildEventKey({ city: "Salvador", neighborhood: "Pirajá", mainReason: "Tiroteio" });
    assert.equal(k, "salvador|piraja|tiroteio");
  });

  it("é insensível a acentos e capitalização (mesmo evento, fontes diferentes)", () => {
    const a = buildEventKey({ city: "Salvador", neighborhood: "Pirajá", mainReason: "Tiroteio" });
    const b = buildEventKey({ city: "salvador", neighborhood: "piraja", mainReason: "TIROTEIO" });
    const c = buildEventKey({ city: " SALVADOR ", neighborhood: " Pirajá ", mainReason: " tiroteio " });
    assert.equal(a, b);
    assert.equal(a, c);
  });

  it("tipos diferentes geram chaves diferentes (não fundir tiroteio com roubo)", () => {
    const tiroteio = buildEventKey({ city: "Salvador", neighborhood: "Pirajá", mainReason: "Tiroteio" });
    const roubo = buildEventKey({ city: "Salvador", neighborhood: "Pirajá", mainReason: "Roubo" });
    assert.notEqual(tiroteio, roubo);
  });

  it("bairros diferentes geram chaves diferentes", () => {
    const a = buildEventKey({ city: "Salvador", neighborhood: "Pirajá", mainReason: "Tiroteio" });
    const b = buildEventKey({ city: "Salvador", neighborhood: "Itapuã", mainReason: "Tiroteio" });
    assert.notEqual(a, b);
  });

  it("sem bairro vira sentinel _centroid (notícia com só cidade)", () => {
    const k = buildEventKey({ city: "Salvador", neighborhood: null, mainReason: "Tiroteio" });
    assert.equal(k, "salvador|_centroid|tiroteio");
  });

  it("geocodeMethod=city-centroid força _centroid mesmo com nome de bairro", () => {
    // Bairro foi extraído mas o geocoder caiu no centroide da cidade. A
    // chave deve refletir a precisão real do geocoding, não o nome bruto.
    const k = buildEventKey({
      city: "Salvador",
      neighborhood: "Salvador",
      mainReason: "Tiroteio",
      geocodeMethod: "city-centroid",
    });
    assert.equal(k, "salvador|_centroid|tiroteio");
  });

  it("nomes compostos viram underscore (Lauro de Freitas)", () => {
    const k = buildEventKey({
      city: "Lauro de Freitas",
      neighborhood: "Vilas do Atlântico",
      mainReason: "Ação policial",
    });
    assert.equal(k, "lauro_de_freitas|vilas_do_atlantico|acao_policial");
  });

  it("descarta caracteres não-alfanuméricos do tipo (sufixos editoriais)", () => {
    const k = buildEventKey({ city: "Salvador", neighborhood: "Pirajá", mainReason: "Roubo!" });
    assert.equal(k, "salvador|piraja|roubo");
  });
});
