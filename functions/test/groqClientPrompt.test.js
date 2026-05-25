"use strict";

const { test } = require("node:test");
const assert = require("node:assert/strict");

const { _internal } = require("../lib/groqClient");
const { buildUserPrompt, MAX_BODY_CHARS } = _internal;

test("buildUserPrompt sem corpo mantém formato título+descrição", () => {
  const p = buildUserPrompt("Tiroteio em Pirajá", "Dois feridos", "");
  assert.match(p, /Título: Tiroteio em Pirajá/);
  assert.match(p, /Descrição: Dois feridos/);
  assert.doesNotMatch(p, /Corpo da matéria/);
});

test("buildUserPrompt sem descrição usa placeholder", () => {
  const p = buildUserPrompt("Título X", "", "");
  assert.match(p, /Descrição: \(sem descrição\)/);
});

test("buildUserPrompt inclui o corpo quando há", () => {
  const p = buildUserPrompt("T", "D", "O fato ocorreu no bairro de São Caetano.");
  assert.match(p, /Corpo da matéria: O fato ocorreu no bairro de São Caetano\./);
});

test("buildUserPrompt corta o corpo em MAX_BODY_CHARS", () => {
  const body = "x".repeat(MAX_BODY_CHARS + 500);
  const p = buildUserPrompt("T", "D", body);
  const marker = "Corpo da matéria: ";
  const corpo = p.slice(p.indexOf(marker) + marker.length);
  assert.equal(corpo.length, MAX_BODY_CHARS);
});

test("buildUserPrompt ignora corpo só com espaços", () => {
  const p = buildUserPrompt("T", "D", "    \n   ");
  assert.doesNotMatch(p, /Corpo da matéria/);
});
