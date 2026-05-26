"use strict";

const { describe, it } = require("node:test");
const assert = require("node:assert/strict");

const { _internal } = require("../lib/newsIngest");
const { sha1, mapType, TYPE_MAP, maxItemsFor, DIRECT_MAX_ITEMS, GNEWS_MAX_ITEMS } =
  _internal;

describe("newsIngest.maxItemsFor", () => {
  it("portal direto puxa mais itens (corpo legível)", () => {
    assert.equal(maxItemsFor({ url: "https://g1.globo.com/rss/g1/bahia/" }), DIRECT_MAX_ITEMS);
    assert.equal(maxItemsFor({ url: "https://www.atarde.com.br/rss" }), DIRECT_MAX_ITEMS);
  });
  it("Google News puxa menos (sem corpo, cai no centróide)", () => {
    assert.equal(
      maxItemsFor({ url: "https://news.google.com/rss/search?q=tiroteio" }),
      GNEWS_MAX_ITEMS,
    );
  });
  it("direto > google news", () => {
    assert.ok(DIRECT_MAX_ITEMS > GNEWS_MAX_ITEMS);
  });
});

describe("newsIngest.sha1", () => {
  it("retorna sempre 40 caracteres hex (sha1 padrão)", () => {
    const hash = sha1("https://exemplo.com/noticia");
    assert.equal(hash.length, 40);
    assert.match(hash, /^[a-f0-9]{40}$/);
  });

  it("é determinístico: mesma entrada produz mesmo hash", () => {
    const a = sha1("https://atarde.com.br/noticia/12345");
    const b = sha1("https://atarde.com.br/noticia/12345");
    assert.equal(a, b);
  });

  it("entradas diferentes produzem hashes diferentes", () => {
    const a = sha1("https://atarde.com.br/noticia/1");
    const b = sha1("https://atarde.com.br/noticia/2");
    assert.notEqual(a, b);
  });

  it("muda completamente com mudança mínima de input (efeito avalanche)", () => {
    const a = sha1("https://example.com/a");
    const b = sha1("https://example.com/b");
    // Conta caracteres diferentes — deve ser alto (não é só 1 char)
    let diff = 0;
    for (let i = 0; i < a.length; i++) {
      if (a[i] !== b[i]) diff++;
    }
    assert.ok(diff > 20, `Esperado >20 chars diferentes, recebido ${diff}`);
  });
});

describe("newsIngest.mapType", () => {
  it("retorna 'Outros' para null, undefined ou vazio", () => {
    assert.equal(mapType(null), "Outros");
    assert.equal(mapType(undefined), "Outros");
    assert.equal(mapType(""), "Outros");
  });

  it("mapeia tipos canônicos do Groq para PT-BR", () => {
    assert.equal(mapType("tiroteio"), "Tiroteio");
    assert.equal(mapType("homicidio"), "Homicídio");
    assert.equal(mapType("roubo"), "Roubo");
    assert.equal(mapType("acao_policial"), "Ação policial");
    assert.equal(mapType("sequestro"), "Sequestro");
    assert.equal(mapType("agressao"), "Agressão");
    assert.equal(mapType("outros"), "Outros");
  });

  it("é case-insensitive (Groq pode retornar com qualquer caixa)", () => {
    assert.equal(mapType("TIROTEIO"), "Tiroteio");
    assert.equal(mapType("Tiroteio"), "Tiroteio");
    assert.equal(mapType("tIrOtEiO"), "Tiroteio");
  });

  it("retorna 'Outros' para tipos não mapeados (defensivo contra LLM hallucinations)", () => {
    assert.equal(mapType("guerra"), "Outros");
    assert.equal(mapType("acidente"), "Outros");
    assert.equal(mapType("xyz123"), "Outros");
  });
});

describe("newsIngest.TYPE_MAP", () => {
  it("contém todos os tipos canônicos esperados pelo prompt do Groq", () => {
    const esperados = [
      "tiroteio",
      "homicidio",
      "roubo",
      "acao_policial",
      "sequestro",
      "agressao",
      "outros",
    ];
    for (const tipo of esperados) {
      assert.ok(
        Object.prototype.hasOwnProperty.call(TYPE_MAP, tipo),
        `TYPE_MAP deve conter "${tipo}"`
      );
    }
  });

  it("nenhum valor é vazio ou null", () => {
    for (const [chave, valor] of Object.entries(TYPE_MAP)) {
      assert.ok(valor && valor.length > 0, `TYPE_MAP["${chave}"] não pode estar vazio`);
    }
  });
});
