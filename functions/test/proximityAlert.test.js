"use strict";

const { describe, it } = require("node:test");
const assert = require("node:assert/strict");

const { _internal } = require("../lib/proximityAlert");
const { mapReason } = _internal;

describe("proximityAlert.mapReason", () => {
  it("retorna 'Relato' para null ou undefined", () => {
    assert.equal(mapReason(null), "Relato");
    assert.equal(mapReason(undefined), "Relato");
    assert.equal(mapReason(""), "Relato");
  });

  it("mapeia tipos canônicos para texto editorial não-alarmista", () => {
    assert.equal(mapReason("Tiroteio"), "Tiroteio reportado");
    assert.equal(mapReason("Homicídio"), "Homicídio reportado");
    assert.equal(mapReason("Roubo"), "Roubo reportado");
    assert.equal(mapReason("Agressão"), "Agressão reportada");
    assert.equal(mapReason("Sequestro"), "Sequestro reportado");
    assert.equal(mapReason("Briga"), "Briga reportada");
  });

  it("mantém termos policiais sem sufixo 'reportado' (são fatos oficiais)", () => {
    assert.equal(mapReason("Ação policial"), "Ação policial");
    assert.equal(mapReason("Operação policial"), "Operação policial");
  });

  it("traduz 'Outros' para texto neutro 'Relato registrado'", () => {
    assert.equal(mapReason("Outros"), "Relato registrado");
  });

  it("retorna o valor original para tipos não mapeados (fallback)", () => {
    assert.equal(mapReason("Furto"), "Furto");
    assert.equal(mapReason("Desconhecido"), "Desconhecido");
  });

  it("NÃO contém palavras alarmistas como 'PERIGO' ou 'CUIDADO'", () => {
    const tipos = [
      "Tiroteio",
      "Homicídio",
      "Roubo",
      "Ação policial",
      "Operação policial",
      "Agressão",
      "Sequestro",
      "Briga",
      "Outros",
    ];
    const proibidas = ["PERIGO", "CUIDADO", "ALERTA", "URGENTE", "EVITE"];
    for (const t of tipos) {
      const resultado = mapReason(t);
      for (const p of proibidas) {
        assert.ok(
          !resultado.toUpperCase().includes(p),
          `mapReason("${t}") = "${resultado}" não pode conter "${p}" (tom editorial)`
        );
      }
    }
  });
});
