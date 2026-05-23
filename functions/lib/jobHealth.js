"use strict";

/**
 * Healthcheck dos schedulers do Faro.
 *
 * Cada Cloud Function que precisa aparecer no painel admin chama
 * `recordSuccess` ou `recordError` no fim do seu run. O helper grava
 * em `/system_health/{jobName}` um doc enxuto com:
 *   - lastRunAt (timestamp)
 *   - lastSuccessAt (timestamp, só se passou)
 *   - lastStatus: "ok" | "error"
 *   - lastError?: string (mensagem da última falha)
 *   - itemsWritten?: number
 *   - durationMs: number
 *
 * Princípio operacional: healthcheck NUNCA pode quebrar o job. Toda
 * escrita é envolvida em try/catch interno — se Firestore estiver
 * indisponível, o cron continua e a falha do healthcheck só vai pro
 * Cloud Logging.
 *
 * Uso típico (em qualquer scheduler):
 *
 *   const { runWithHealth } = require("./jobHealth");
 *
 *   exports.fooJob = onSchedule({...}, async () => {
 *     return runWithHealth("fooJob", async () => {
 *       // lógica original do job — pode retornar { itemsWritten: 42 }
 *       return { itemsWritten: 42 };
 *     });
 *   });
 *
 * Se o handler lançar, `runWithHealth` registra erro e re-lança pra
 * preservar a política de retry do Cloud Scheduler (3 tentativas com
 * backoff exponencial por default).
 */

const admin = require("firebase-admin");
const { logger } = require("firebase-functions/v2");

const COLLECTION = "system_health";

/**
 * Envolve a lógica do job, mede duração, registra healthcheck e
 * re-lança em caso de erro.
 *
 * @param {string} name id estável do job (vira o doc id em /system_health)
 * @param {() => Promise<{itemsWritten?: number}|void>} handler
 * @returns {Promise<any>} o que o handler retornou
 */
async function runWithHealth(name, handler) {
  const start = Date.now();
  try {
    const result = (await handler()) || {};
    const durationMs = Date.now() - start;
    await recordSuccess(name, {
      itemsWritten: typeof result.itemsWritten === "number" ? result.itemsWritten : null,
      durationMs,
    });
    return result;
  } catch (e) {
    const durationMs = Date.now() - start;
    await recordError(name, { error: e, durationMs });
    throw e;
  }
}

async function recordSuccess(name, { itemsWritten = null, durationMs = null } = {}) {
  try {
    const now = admin.firestore.FieldValue.serverTimestamp();
    await admin
      .firestore()
      .collection(COLLECTION)
      .doc(name)
      .set(
        {
          name,
          lastStatus: "ok",
          lastRunAt: now,
          lastSuccessAt: now,
          lastError: admin.firestore.FieldValue.delete(),
          itemsWritten: itemsWritten ?? admin.firestore.FieldValue.delete(),
          durationMs: durationMs ?? admin.firestore.FieldValue.delete(),
        },
        { merge: true },
      );
  } catch (e) {
    logger.warn(`jobHealth: falha ao gravar success de ${name}: ${e.message || e}`);
  }
}

async function recordError(name, { error, durationMs = null } = {}) {
  try {
    const message =
      (error && error.message) ||
      (error && error.toString && error.toString()) ||
      "unknown";
    await admin
      .firestore()
      .collection(COLLECTION)
      .doc(name)
      .set(
        {
          name,
          lastStatus: "error",
          lastRunAt: admin.firestore.FieldValue.serverTimestamp(),
          lastError: String(message).slice(0, 500),
          durationMs: durationMs ?? admin.firestore.FieldValue.delete(),
        },
        { merge: true },
      );
  } catch (e) {
    logger.warn(`jobHealth: falha ao gravar error de ${name}: ${e.message || e}`);
  }
}

exports.runWithHealth = runWithHealth;
exports.recordSuccess = recordSuccess;
exports.recordError = recordError;
