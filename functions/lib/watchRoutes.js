"use strict";

/**
 * Vigia trajetos salvos (V2 da Frente 5 — rota A→B).
 *
 * O usuário salva um trajeto (origem→destino) em /users/{uid}/watchedRoutes.
 * Este scheduler roda a cada 30 min, e pra cada trajeto observado checa se
 * apareceu ocorrência NOVA (depois do último check) dentro do corredor.
 * Se sim, manda um push editorial pro dono — informativo, nunca alarmista.
 *
 * Princípio editorial: o aviso descreve ("2 relatos novos no seu trajeto"),
 * não recomenda nem assusta. Sem PERIGO/CUIDADO/EVITE/URGENTE.
 *
 * Eficiência: busca as ocorrências recentes UMA vez (janela que cobre o
 * intervalo do scheduler) e filtra por corredor em memória pra cada rota.
 * Suficiente pra escala do beta; quando crescer, migrar pra índice
 * geoespacial.
 */

const admin = require("firebase-admin");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { logger } = require("firebase-functions/v2");

const { runWithHealth } = require("./jobHealth");
const { pointInCorridor } = require("./routeCorridor");

// Janela de busca de ocorrências recentes. Cobre o intervalo do scheduler
// (30 min) com folga, pra não perder nada entre runs.
const LOOKBACK_MS = 40 * 60 * 1000;
const DEFAULT_CORRIDOR_M = 500;
const MAX_ALERT_COUNT = 9; // teto exibido no texto ("9+")

/**
 * Filtra, de uma lista de ocorrências recentes, as que são NOVAS pra um
 * trajeto (depois do lastChecked) E caem no corredor. Pura e testável.
 *
 * @param {Array<{latitude:number, longitude:number, dateMs:number}>} occ
 * @param {{originLat,originLng,destLat,destLng,corridorMeters,lastCheckedMs}} route
 */
function newOccurrencesForRoute(occ, route) {
  const bufferKm = (route.corridorMeters || DEFAULT_CORRIDOR_M) / 1000;
  return occ.filter((o) => {
    if (typeof o.dateMs === "number" && o.dateMs <= route.lastCheckedMs) {
      return false;
    }
    return pointInCorridor(
      o.latitude,
      o.longitude,
      route.originLat,
      route.originLng,
      route.destLat,
      route.destLng,
      bufferKm,
    );
  });
}

/**
 * Texto editorial do push. Informativo, nunca alarmista. Pura.
 */
function buildRouteAlertText(label, count) {
  const onde = label && String(label).trim().length > 0
    ? `no trajeto ${String(label).trim()}`
    : "no seu trajeto";
  const n = count > MAX_ALERT_COUNT ? `${MAX_ALERT_COUNT}+` : `${count}`;
  const rel = count === 1 ? "1 relato novo" : `${n} relatos novos`;
  return `${rel} ${onde} nas últimas horas.`;
}

exports.watchRoutes = onSchedule(
  {
    schedule: "every 30 minutes",
    timeZone: "America/Bahia",
    region: "southamerica-east1",
    memory: "512MiB",
    timeoutSeconds: 540,
  },
  async () => runWithHealth("watchRoutes", async () => {
    const db = admin.firestore();
    const now = Date.now();
    const since = new Date(now - LOOKBACK_MS);

    // Busca as ocorrências recentes uma vez só.
    const occSnap = await db
      .collection("occurrences")
      .where("date", ">", admin.firestore.Timestamp.fromDate(since))
      .orderBy("date", "desc")
      .limit(500)
      .get();
    const recent = occSnap.docs.map((d) => {
      const o = d.data();
      return {
        latitude: o.latitude,
        longitude: o.longitude,
        dateMs: o.date?.toMillis ? o.date.toMillis() : 0,
      };
    });

    if (recent.length === 0) {
      return { itemsWritten: 0 };
    }

    // Todos os trajetos observados, de todos os usuários.
    const routesSnap = await db.collectionGroup("watchedRoutes").get();
    let alerts = 0;

    for (const routeDoc of routesSnap.docs) {
      const r = routeDoc.data();
      if (r.active === false) continue;
      const uid = routeDoc.ref.parent.parent && routeDoc.ref.parent.parent.id;
      if (!uid) continue;

      const lastCheckedMs = r.lastCheckedAt?.toMillis
        ? r.lastCheckedAt.toMillis()
        : 0;

      const hits = newOccurrencesForRoute(recent, {
        originLat: r.originLat,
        originLng: r.originLng,
        destLat: r.destLat,
        destLng: r.destLng,
        corridorMeters: r.corridorMeters,
        lastCheckedMs,
      });

      // Sempre avança o lastCheckedAt, mesmo sem hits — assim o próximo run
      // não reconsidera as mesmas ocorrências.
      await routeDoc.ref.update({
        lastCheckedAt: admin.firestore.Timestamp.fromMillis(now),
      });

      if (hits.length === 0) continue;

      const token = await pickFcmToken(db, uid);
      if (!token) continue;

      try {
        await admin.messaging().send({
          token,
          notification: {
            title: "Faro · trajeto",
            body: buildRouteAlertText(r.label, hits.length),
          },
          data: { type: "route_watch", routeId: routeDoc.id, count: String(hits.length) },
          android: { notification: { channelId: "faro_routes", priority: "default" } },
          apns: { payload: { aps: { sound: "default" } } },
        });
        alerts++;
      } catch (e) {
        if (e.code === "messaging/registration-token-not-registered") {
          await db
            .collection("users").doc(uid)
            .collection("fcmTokens").doc(token)
            .delete().catch(() => {});
        } else {
          logger.warn(`watchRoutes push falhou uid=${uid}: ${e.message || e}`);
        }
      }
    }

    logger.info(`watchRoutes: ${alerts} alertas enviados`);
    return { itemsWritten: alerts };
  }),
);

async function pickFcmToken(db, uid) {
  try {
    const snap = await db
      .collection("users").doc(uid)
      .collection("fcmTokens")
      .orderBy("updatedAt", "desc")
      .limit(1)
      .get();
    return snap.empty ? null : snap.docs[0].id;
  } catch (_) {
    return null;
  }
}

exports._internal = {
  newOccurrencesForRoute,
  buildRouteAlertText,
  LOOKBACK_MS,
  DEFAULT_CORRIDOR_M,
};
