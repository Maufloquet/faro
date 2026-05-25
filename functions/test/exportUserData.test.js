"use strict";

const { test } = require("node:test");
const assert = require("node:assert/strict");

const { _internal } = require("../lib/exportUserData");
const { buildExportBundle, serialize } = _internal;

// Stub de Timestamp do admin SDK: o que importa é ter toDate().
function ts(iso) {
  return { toDate: () => new Date(iso) };
}

test("serialize converte Timestamp (toDate) em ISO 8601", () => {
  assert.equal(serialize(ts("2026-05-25T10:00:00.000Z")), "2026-05-25T10:00:00.000Z");
});

test("serialize converte Date nativo em ISO 8601", () => {
  const d = new Date("2026-01-02T03:04:05.000Z");
  assert.equal(serialize(d), "2026-01-02T03:04:05.000Z");
});

test("serialize converte {_seconds,_nanoseconds} em ISO 8601", () => {
  const epoch = serialize({ _seconds: 0, _nanoseconds: 0 });
  assert.equal(epoch, "1970-01-01T00:00:00.000Z");
});

test("serialize desce em objetos e arrays aninhados", () => {
  const input = {
    nome: "x",
    quando: ts("2026-05-25T00:00:00.000Z"),
    lista: [{ at: ts("2026-05-24T00:00:00.000Z") }, 42],
  };
  const out = serialize(input);
  assert.equal(out.nome, "x");
  assert.equal(out.quando, "2026-05-25T00:00:00.000Z");
  assert.equal(out.lista[0].at, "2026-05-24T00:00:00.000Z");
  assert.equal(out.lista[1], 42);
});

test("serialize preserva primitivos e null", () => {
  assert.equal(serialize("texto"), "texto");
  assert.equal(serialize(7), 7);
  assert.equal(serialize(true), true);
  assert.equal(serialize(null), null);
});

test("buildExportBundle monta as quatro categorias com chaves PT-BR", () => {
  const bundle = buildExportBundle({
    uid: "abc",
    token: { email: "a@b.com", name: "Ana", firebase: { sign_in_provider: "google.com" } },
    profile: { mainNeighborhood: "Pituba", criadoEm: ts("2026-01-01T00:00:00.000Z") },
    favorites: [{ id: "pituba", name: "Pituba", lat: -13, lng: -38 }],
    fcmTokens: [{ id: "tok1", platform: "android", updatedAt: ts("2026-05-01T00:00:00.000Z") }],
    contestations: [{ id: "abc_occ1", occurrenceId: "occ1", reason: "naoAconteceu", submittedAt: ts("2026-04-01T00:00:00.000Z") }],
    exportedAt: new Date("2026-05-25T12:00:00.000Z"),
  });

  assert.equal(bundle.uid, "abc");
  assert.equal(bundle.email, "a@b.com");
  assert.equal(bundle.displayName, "Ana");
  assert.equal(bundle.anonimo, false);
  assert.equal(bundle.exportadoEm, "2026-05-25T12:00:00.000Z");
  assert.equal(bundle.perfil.mainNeighborhood, "Pituba");
  assert.equal(bundle.perfil.criadoEm, "2026-01-01T00:00:00.000Z");
  assert.equal(bundle.favoritos.length, 1);
  assert.equal(bundle.tokensDePush[0].updatedAt, "2026-05-01T00:00:00.000Z");
  assert.equal(bundle.contestacoes[0].submittedAt, "2026-04-01T00:00:00.000Z");
});

test("buildExportBundle marca anonimo=true pra login anônimo", () => {
  const bundle = buildExportBundle({
    uid: "x",
    token: { firebase: { sign_in_provider: "anonymous" } },
    profile: null,
    favorites: [],
    fcmTokens: [],
    contestations: [],
    exportedAt: new Date("2026-05-25T00:00:00.000Z"),
  });
  assert.equal(bundle.anonimo, true);
  assert.equal(bundle.email, null);
  assert.deepEqual(bundle.perfil, {});
  assert.deepEqual(bundle.favoritos, []);
});

test("buildExportBundle é JSON-serializável (sem Timestamp cru sobrando)", () => {
  const bundle = buildExportBundle({
    uid: "x",
    token: {},
    profile: { quando: ts("2026-05-25T00:00:00.000Z") },
    favorites: [],
    fcmTokens: [],
    contestations: [],
    exportedAt: new Date("2026-05-25T00:00:00.000Z"),
  });
  const round = JSON.parse(JSON.stringify(bundle));
  assert.equal(round.perfil.quando, "2026-05-25T00:00:00.000Z");
});
