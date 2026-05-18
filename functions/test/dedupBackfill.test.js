"use strict";

const { describe, it } = require("node:test");
const assert = require("node:assert/strict");

const { _internal } = require("../lib/dedupBackfill");
const { groupDuplicates, buildCorroboration } = _internal;

const H = 60 * 60 * 1000;

function mk(id, eventKey, dateMs, extras = {}) {
  return { id, eventKey, dateMs, ...extras };
}

describe("dedupBackfill.groupDuplicates", () => {
  it("lista vazia → nenhum grupo", () => {
    assert.deepEqual(groupDuplicates([]), []);
  });

  it("docs sem eventKey são ignorados (não agrupáveis)", () => {
    const items = [
      mk("a", null, 0),
      mk("b", null, H),
    ];
    assert.deepEqual(groupDuplicates(items), []);
  });

  it("doc único forma grupo de tamanho 1 (sem duplicates)", () => {
    const items = [mk("a", "salvador|piraja|tiroteio", 0)];
    const groups = groupDuplicates(items);
    assert.equal(groups.length, 1);
    assert.equal(groups[0].canonical.id, "a");
    assert.deepEqual(groups[0].duplicates, []);
  });

  it("dois docs com mesma eventKey dentro da janela: agrupa", () => {
    const items = [
      mk("a", "salvador|piraja|tiroteio", 0),
      mk("b", "salvador|piraja|tiroteio", 2 * H),
    ];
    const groups = groupDuplicates(items);
    assert.equal(groups.length, 1);
    assert.equal(groups[0].canonical.id, "a"); // mais antigo
    assert.equal(groups[0].duplicates.length, 1);
    assert.equal(groups[0].duplicates[0].id, "b");
  });

  it("docs com mesma eventKey fora da janela: dois grupos separados", () => {
    const items = [
      mk("a", "salvador|piraja|tiroteio", 0),
      mk("b", "salvador|piraja|tiroteio", 10 * H), // bem fora da janela de 6h
    ];
    const groups = groupDuplicates(items);
    assert.equal(groups.length, 2);
    assert.equal(groups[0].duplicates.length, 0);
    assert.equal(groups[1].duplicates.length, 0);
  });

  it("docs com eventKeys diferentes nunca agrupam (não fundir tiroteio com roubo)", () => {
    const items = [
      mk("a", "salvador|piraja|tiroteio", 0),
      mk("b", "salvador|piraja|roubo", 1 * H),
    ];
    const groups = groupDuplicates(items);
    assert.equal(groups.length, 2);
    assert.equal(groups[0].duplicates.length, 0);
    assert.equal(groups[1].duplicates.length, 0);
  });

  it("ordem de entrada não muda o resultado (canônico = mais antigo)", () => {
    const items = [
      mk("z", "salvador|piraja|tiroteio", 3 * H),
      mk("a", "salvador|piraja|tiroteio", 0),
      mk("m", "salvador|piraja|tiroteio", 1 * H),
    ];
    const groups = groupDuplicates(items);
    assert.equal(groups.length, 1);
    assert.equal(groups[0].canonical.id, "a");
    assert.equal(groups[0].duplicates.length, 2);
    const dupIds = groups[0].duplicates.map((d) => d.id).sort();
    assert.deepEqual(dupIds, ["m", "z"]);
  });

  it("3 docs em sequência, mas 3º está >6h do canônico: forma 2 grupos", () => {
    // Janela é a partir do canônico, não deslizante por elemento.
    // Doc B dentro de 6h de A → agrupa em A.
    // Doc C >6h de A → começa novo grupo (mesmo que esteja perto de B).
    const items = [
      mk("a", "k", 0),
      mk("b", "k", 5 * H),
      mk("c", "k", 8 * H),
    ];
    const groups = groupDuplicates(items);
    assert.equal(groups.length, 2);
    assert.equal(groups[0].canonical.id, "a");
    assert.equal(groups[0].duplicates.length, 1);
    assert.equal(groups[0].duplicates[0].id, "b");
    assert.equal(groups[1].canonical.id, "c");
  });

  it("empate exato de data: desempata por id pra determinismo", () => {
    const items = [
      mk("z", "k", 0),
      mk("a", "k", 0),
    ];
    const groups = groupDuplicates(items);
    assert.equal(groups[0].canonical.id, "a");
    assert.equal(groups[0].duplicates[0].id, "z");
  });
});

describe("dedupBackfill.buildCorroboration", () => {
  it("aceita doc minimal (só source)", () => {
    const c = buildCorroboration({ source: "media" });
    assert.equal(c.source, "media");
    assert.ok(c.addedAt instanceof Date);
  });

  it("inclui sourceProvider, url, title quando presentes (media)", () => {
    const c = buildCorroboration({
      source: "media",
      sourceProvider: "g1-bahia",
      sourceName: "G1 Bahia",
      externalUrl: "https://g1.globo.com/x",
      externalTitle: "Tiroteio em Pirajá",
      confidence: 0.82,
    });
    assert.equal(c.sourceProvider, "g1-bahia");
    assert.equal(c.url, "https://g1.globo.com/x");
    assert.equal(c.title, "Tiroteio em Pirajá");
    assert.equal(c.confidence, 0.82);
  });

  it("inclui externalId pra duplicatas do Fogo Cruzado", () => {
    const c = buildCorroboration({ source: "fogo_cruzado", externalId: "fc-abc" });
    assert.equal(c.externalId, "fc-abc");
  });

  it("source desconhecido vira 'unknown' (defensivo)", () => {
    const c = buildCorroboration({});
    assert.equal(c.source, "unknown");
  });
});
