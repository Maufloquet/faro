"use strict";

/**
 * Push notification por proximidade — V1.5 do P0 §8.1 do relatório.
 *
 * Quando uma ocorrência nova é criada no Firestore, dispara FCM message
 * para o tópico da célula geográfica (geohash precisão 5 ~5km). Apps
 * inscritos nesse tópico recebem push.
 *
 * Estratégia:
 * - App calcula geohash5 baseado na localização atual do usuário
 * - App assina o tópico region-{geohash5}
 * - Backend publica nesse tópico quando ocorrência nova entra
 * - Usuário só recebe push de relatos na própria célula
 *
 * Limitações conhecidas:
 * - Topic-based — sem segmentação por raio fino dentro da célula
 * - Sem rate limiting global ainda (V2: máximo 3 pushes/h por usuário)
 *
 * NÃO dispara em:
 * - Docs com backfilled=true (histórico em batch — não é "novo")
 * - Docs sem geohash (sem coordenada válida)
 *
 * Tom editorial: informativo, não alarmista. Sem "PERIGO" no título.
 */

const admin = require("firebase-admin");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { logger } = require("firebase-functions/v2");

exports.onOccurrenceCreated = onDocumentCreated(
  {
    document: "occurrences/{occurrenceId}",
    region: "southamerica-east1",
    memory: "256MiB",
  },
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    // Skip backfill — não é "novo" pro usuário, é histórico
    if (data.backfilled === true) return;

    // Precisa de geohash pra rotear pro tópico certo
    const geohash5 = typeof data.geohash === "string" ? data.geohash.substring(0, 5) : null;
    if (!geohash5) return;

    const reason = mapReason(data.mainReason);
    const where = data.neighborhood || data.city || "área próxima";

    // Dois tópicos paralelos:
    //   region_{geohash5}    — quem está geograficamente próximo agora
    //   reference_{geohash5} — quem definiu endereço de referência aqui
    // O 2º é pra turista/viajante: notif sobre a área do hotel mesmo se
    // ele não estiver no hotel naquele momento.
    const topics = [
      { name: `region_${geohash5}`, scope: "region" },
      { name: `reference_${geohash5}`, scope: "reference" },
    ];

    for (const t of topics) {
      const message = buildMessage({
        title: t.scope === "reference"
          ? "Próximo do seu endereço salvo"
          : "Faro · novo relato perto",
        body: `${reason} em ${where}`,
        occurrenceId: event.params.occurrenceId,
        geohash5,
        scope: t.scope,
        topic: t.name,
      });
      await sendWithRetry(message, t.name, data.source);
    }
  }
);

/**
 * Envia mensagem FCM com retry exponencial pra falhas transientes
 * (rate limit do FCM, instabilidade momentânea, INTERNAL errors).
 * Códigos de erro não-recuperáveis (INVALID_ARGUMENT, mensagem mal-formada,
 * UNREGISTERED no topic) são logados na primeira tentativa.
 */
async function sendWithRetry(message, topicName, sourceTag, maxAttempts = 3) {
  const RECOVERABLE = new Set([
    "messaging/internal-error",
    "messaging/server-unavailable",
    "messaging/quota-exceeded",
    "messaging/unknown-error",
  ]);
  let lastError;
  for (let attempt = 0; attempt < maxAttempts; attempt++) {
    try {
      await admin.messaging().send(message);
      logger.info(`FCM enviado · topic=${topicName} · type=${sourceTag}`);
      return;
    } catch (e) {
      lastError = e;
      const code = e?.errorInfo?.code || e?.code || "";
      if (!RECOVERABLE.has(code) || attempt === maxAttempts - 1) {
        break;
      }
      const backoff = 500 * Math.pow(2, attempt);
      await new Promise((resolve) => setTimeout(resolve, backoff));
    }
  }
  logger.error(`FCM falhou · topic=${topicName} · ${lastError?.message || lastError}`);
}

function buildMessage({ title, body, occurrenceId, geohash5, scope, topic }) {
  return {
    notification: { title, body },
    data: {
      occurrenceId,
      type: scope === "reference" ? "reference_alert" : "proximity_alert",
      geohash5,
    },
    android: {
      priority: "high",
      notification: { channelId: "faro_proximity" },
    },
    apns: {
      headers: {
        "apns-priority": "10",
        "apns-push-type": "alert",
      },
      payload: {
        aps: {
          sound: "default",
          badge: 1,
          "mutable-content": 1,
          "content-available": 1,
        },
      },
    },
    topic,
  };
}

function mapReason(raw) {
  if (!raw) return "Relato";
  // Tom editorial: usar tipo informativo, sem alarmismo
  const map = {
    "Tiroteio": "Tiroteio reportado",
    "Homicídio": "Homicídio reportado",
    "Roubo": "Roubo reportado",
    "Ação policial": "Ação policial",
    "Operação policial": "Operação policial",
    "Agressão": "Agressão reportada",
    "Sequestro": "Sequestro reportado",
    "Briga": "Briga reportada",
    "Outros": "Relato registrado",
  };
  return map[raw] || raw;
}

// Exportado para testes unitários
exports._internal = { mapReason, buildMessage };
