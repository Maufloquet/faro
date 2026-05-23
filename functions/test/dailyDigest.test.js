"use strict";

const { test } = require("node:test");
const assert = require("node:assert/strict");

const { _internal } = require("../lib/dailyDigest");
const { buildDigestText, normalize } = _internal;

test("normalize remove acento + lowercase + trim", () => {
  assert.equal(normalize("Pelourinho"), "pelourinho");
  assert.equal(normalize("Pirajá"), "piraja");
  assert.equal(normalize("  São Caetano  "), "sao caetano");
});

test("normalize tolera null/empty", () => {
  assert.equal(normalize(null), "");
  assert.equal(normalize(undefined), "");
  assert.equal(normalize(""), "");
});

test("buildDigestText usa nome do usuário quando há", () => {
  const text = buildDigestText(
    { totalCount: 3, topReason: null, topReasonCount: 0, neighborhoods: ["Pirajá"] },
    "Mauricio",
  );
  assert.match(text, /Bom dia, Mauricio\./);
  assert.match(text, /3 relatos em Pirajá/);
});

test("buildDigestText cai pra 'Bom dia.' sem nome", () => {
  const text = buildDigestText(
    { totalCount: 2, topReason: null, topReasonCount: 0, neighborhoods: ["Pituba"] },
    null,
  );
  assert.match(text, /^Bom dia\. /);
});

test("buildDigestText singular pra 1 relato", () => {
  const text = buildDigestText(
    { totalCount: 1, topReason: null, topReasonCount: 0, neighborhoods: ["Centro"] },
    null,
  );
  assert.match(text, /1 relato/);
  assert.doesNotMatch(text, /1 relatos/);
});

test("buildDigestText cita topReason quando representa >= 50%", () => {
  const text = buildDigestText(
    {
      totalCount: 4,
      topReason: "Tiroteio",
      topReasonCount: 3,
      neighborhoods: ["Pirajá"],
    },
    null,
  );
  assert.match(text, /Principal motivo: tiroteio/i);
});

test("buildDigestText omite topReason quando representa menos de 50%", () => {
  const text = buildDigestText(
    {
      totalCount: 5,
      topReason: "Tiroteio",
      topReasonCount: 2,
      neighborhoods: ["Pirajá"],
    },
    null,
  );
  assert.doesNotMatch(text, /Principal motivo/);
});

test("buildDigestText fala 'seus bairros' quando há múltiplos", () => {
  const text = buildDigestText(
    {
      totalCount: 3,
      topReason: null,
      topReasonCount: 0,
      neighborhoods: ["Pituba", "Iguatemi"],
    },
    null,
  );
  assert.match(text, /em seus bairros/);
});

test("buildDigestText nunca contém palavras alarmistas", () => {
  const text = buildDigestText(
    {
      totalCount: 10,
      topReason: "Tiroteio",
      topReasonCount: 9,
      neighborhoods: ["Pirajá"],
    },
    "Mauricio",
  );
  for (const banned of ["PERIGO", "CUIDADO", "EVITE", "URGENTE", "perigosa"]) {
    assert.doesNotMatch(text, new RegExp(banned, "i"), `texto contém "${banned}"`);
  }
});
