"use strict";

const { test } = require("node:test");
const assert = require("node:assert/strict");

const { runWithHealth } = require("../lib/jobHealth");

// Nota: o helper tenta escrever no Firestore via Admin SDK. Como aqui
// não há `admin.initializeApp()`, cada escrita falha — mas o helper
// envolve toda gravação num try/catch interno, então o handler não é
// afetado. Os testes verificam só o contrato externo: retorno em sucesso
// e re-lançamento em erro.

test("runWithHealth devolve o que o handler retornou em sucesso", async () => {
  const out = await runWithHealth("test_job_ok", async () => ({ itemsWritten: 42 }));
  assert.deepEqual(out, { itemsWritten: 42 });
});

test("runWithHealth tolera handler que retorna void", async () => {
  const out = await runWithHealth("test_job_void", async () => {});
  assert.deepEqual(out, {});
});

test("runWithHealth re-lança erro do handler pra preservar retry do scheduler", async () => {
  const boom = new Error("handler quebrou");
  await assert.rejects(
    () => runWithHealth("test_job_err", async () => {
      throw boom;
    }),
    /handler quebrou/,
  );
});
