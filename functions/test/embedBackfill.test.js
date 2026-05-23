"use strict";

const { test } = require("node:test");
const assert = require("node:assert/strict");

const { _internal } = require("../lib/embedBackfill");
const { canonicalText } = _internal;

test("canonicalText prioriza externalTitle quando presente", () => {
  const text = canonicalText({
    externalTitle: "Tiroteio deixa três feridos em Pirajá",
    mainReason: "Tiroteio",
    neighborhood: "Pirajá",
    city: "Salvador",
  });
  assert.equal(text, "Tiroteio deixa três feridos em Pirajá");
});

test("canonicalText monta descritor quando não há título", () => {
  const text = canonicalText({
    mainReason: "Tiroteio",
    neighborhood: "Pirajá",
    city: "Salvador",
    state: "Bahia",
  });
  assert.equal(text, "Tiroteio — Pirajá — Salvador — Bahia");
});

test("canonicalText tolera campos ausentes", () => {
  const text = canonicalText({ mainReason: "Roubo" });
  assert.equal(text, "Roubo");
});

test("canonicalText nunca devolve string vazia", () => {
  const text = canonicalText({});
  assert.equal(text, "ocorrência sem descrição");
});

test("canonicalText trunca em 2000 chars", () => {
  const longTitle = "a".repeat(5000);
  const text = canonicalText({ externalTitle: longTitle });
  assert.equal(text.length, 2000);
});
