"use strict";

const { describe, it } = require("node:test");
const assert = require("node:assert/strict");

const { _internal } = require("../lib/osmNotesIngest");
const { hasSecurityKeyword, inferReason, parseNoteDate, isOpen } = _internal;

const note = (text, opts = {}) => ({
  id: 1,
  lat: -12.97,
  lon: -38.5,
  status: opts.status || "open",
  comments: [{ text, date: opts.date || "2026-05-01 12:00:00 UTC" }],
});

describe("osmNotesIngest.hasSecurityKeyword", () => {
  it("aceita texto com keyword direta", () => {
    assert.equal(hasSecurityKeyword(note("muito assalto nessa esquina")), true);
    assert.equal(hasSecurityKeyword(note("tiroteio na semana passada")), true);
  });

  it("rejeita texto sem nenhuma keyword (falso positivo do search)", () => {
    assert.equal(
      hasSecurityKeyword(note("ponto de ônibus sem cobertura")),
      false,
    );
  });

  it("case insensitive", () => {
    assert.equal(hasSecurityKeyword(note("ASSALTO recorrente")), true);
  });

  it("comment vazio = false", () => {
    assert.equal(hasSecurityKeyword({ comments: [] }), false);
  });
});

describe("osmNotesIngest.inferReason", () => {
  it("infere Roubo de 'assalto'/'roubo'", () => {
    assert.equal(inferReason(note("assalto à mão armada")), "Roubo");
    assert.equal(inferReason(note("roubo de celular")), "Roubo");
  });

  it("infere Tiroteio", () => {
    assert.equal(inferReason(note("tiroteio noturno")), "Tiroteio");
  });

  it("infere Agressão de 'violência'/'agressão'", () => {
    assert.equal(inferReason(note("agressão física")), "Agressão");
    assert.equal(inferReason(note("violência doméstica")), "Agressão");
  });

  it("fallback Outros quando não tem match específico", () => {
    assert.equal(inferReason(note("evitar à noite")), "Outros");
    assert.equal(inferReason(note("perigoso transitar")), "Outros");
  });
});

describe("osmNotesIngest.parseNoteDate", () => {
  it("parseia formato OSM 'YYYY-MM-DD HH:MM:SS UTC'", () => {
    const d = parseNoteDate(note("x", { date: "2026-05-18 14:30:00 UTC" }));
    assert.ok(d instanceof Date);
    assert.equal(d.getUTCFullYear(), 2026);
    assert.equal(d.getUTCMonth(), 4); // maio = índice 4
    assert.equal(d.getUTCDate(), 18);
  });

  it("retorna null pra data ausente", () => {
    assert.equal(parseNoteDate({ comments: [{}] }), null);
  });
});

describe("osmNotesIngest.isOpen", () => {
  it("open passa", () => {
    assert.equal(isOpen(note("x")), true);
  });
  it("closed bloqueia", () => {
    assert.equal(isOpen(note("x", { status: "closed" })), false);
  });
});
