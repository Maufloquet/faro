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

    const topic = `region_${geohash5}`;
    const reason = mapReason(data.mainReason);
    const where = data.neighborhood || data.city || "área próxima";

    const message = {
      notification: {
        title: "Faro · novo relato perto",
        body: `${reason} em ${where}`,
      },
      data: {
        occurrenceId: event.params.occurrenceId,
        type: "proximity_alert",
        geohash5,
      },
      android: {
        priority: "high",
        notification: {
          channelId: "faro_proximity",
        },
      },
      apns: {
        // headers garantem entrega imediata + categoria de alerta
        headers: {
          "apns-priority": "10",
          "apns-push-type": "alert",
        },
        payload: {
          aps: {
            sound: "default",
            badge: 1,
            // mutable-content permite que extension service modifique
            // o payload antes de mostrar (útil pra ricos/imagens futuras)
            "mutable-content": 1,
            // content-available acorda o app brevemente pra processar
            // a entrega — útil pra atualização de badge/lista mesmo
            // antes do usuário tocar
            "content-available": 1,
          },
        },
      },
      topic,
    };

    try {
      await admin.messaging().send(message);
      logger.info(`FCM enviado · topic=${topic} · type=${data.source}`);
    } catch (e) {
      logger.error(`FCM falhou · topic=${topic} · ${e.message}`);
    }
  }
);

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
exports._internal = { mapReason };
