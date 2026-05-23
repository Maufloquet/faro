"use strict";

/**
 * Agrega histórico de relatos por bairro pra dar contexto editorial à UI.
 *
 * Pergunta que isso responde: "X relatos esta semana é muito ou pouco pra
 * esse bairro?" — sem essa baseline, o app mostra um número solto que pode
 * parecer alarmante quando é só a média histórica, ou tranquilo quando é
 * um pico real.
 *
 * Tom editorial: nunca virar "área perigosa" ou ranking. Sempre comparar
 * o bairro consigo mesmo, no tempo. Tendência é informação; veredito não.
 *
 * Lê /occurrences dos últimos 90d, agrupa por (state, city, neighborhood)
 * e escreve em /historical_baseline/{regionKey} com:
 *   - totalOccurrences (na janela)
 *   - weeklyAverage (média de relatos por semana ao longo da janela)
 *   - recentWeekCount (relatos nos últimos 7d)
 *   - trend: "up" | "down" | "stable" | "insufficient_data"
 *   - topReasons (até 3, ordenadas)
 *   - windowDays, sampledAt
 *
 * Bairros com menos de 5 relatos no histórico ficam com trend
 * "insufficient_data" — não há base estatística pra falar de tendência.
 *
 * Scheduler diário (madrugada), idempotente: re-rodar sobrescreve.
 */

const admin = require("firebase-admin");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { logger } = require("firebase-functions/v2");
const { runWithHealth } = require("./jobHealth");

const WINDOW_DAYS = 90;
const RECENT_WINDOW_DAYS = 7;
const MIN_OCCURRENCES_FOR_TREND = 5;
const TREND_UP_THRESHOLD = 1.4;
const TREND_DOWN_THRESHOLD = 0.6;
const MAX_REASONS = 3;

exports.aggregateHistoricalBaseline = onSchedule(
  {
    schedule: "every day 03:30",
    timeZone: "America/Bahia",
    region: "southamerica-east1",
    memory: "512MiB",
    timeoutSeconds: 300,
  },
  async () => runWithHealth("aggregateHistoricalBaseline", async () => {
    const db = admin.firestore();
    const now = new Date();
    const since = new Date(now.getTime() - WINDOW_DAYS * 24 * 60 * 60 * 1000);

    const snap = await db
      .collection("occurrences")
      .where("date", ">=", admin.firestore.Timestamp.fromDate(since))
      .get();

    const occurrences = [];
    snap.forEach((d) => {
      const data = d.data();
      const date =
        data.date && typeof data.date.toDate === "function"
          ? data.date.toDate()
          : null;
      if (!date) return;
      occurrences.push({
        neighborhood: data.neighborhood || null,
        city: data.city || null,
        state: data.state || null,
        mainReason: data.mainReason || null,
        date,
      });
    });

    const baselines = aggregateBaseline(occurrences, {
      windowDays: WINDOW_DAYS,
      recentWindowDays: RECENT_WINDOW_DAYS,
      now,
    });

    let batch = db.batch();
    let inBatch = 0;
    let written = 0;
    for (const [key, payload] of Object.entries(baselines)) {
      const ref = db.collection("historical_baseline").doc(key);
      batch.set(
        ref,
        {
          ...payload,
          sampledAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: false },
      );
      inBatch++;
      written++;
      if (inBatch >= 400) {
        await batch.commit();
        batch = db.batch();
        inBatch = 0;
      }
    }
    if (inBatch > 0) await batch.commit();

    logger.info(
      `historicalBaseline: ${snap.size} occurrences agrupadas em ${written} regiões`,
    );
    return { itemsWritten: written };
  }),
);

/**
 * Lógica pura. Agrupa por (state, city, neighborhood) e devolve baseline
 * por região. Testável sem Firestore.
 *
 * @param {Array<{neighborhood, city, state, mainReason, date}>} occurrences
 * @param {{windowDays: number, recentWindowDays: number, now: Date}} opts
 * @returns {Object<string, Object>} map regionKey → payload
 */
function aggregateBaseline(occurrences, opts) {
  const windowDays = opts.windowDays;
  const recentWindowDays = opts.recentWindowDays;
  const now = opts.now instanceof Date ? opts.now : new Date(opts.now);
  const recentCutoff = new Date(
    now.getTime() - recentWindowDays * 24 * 60 * 60 * 1000,
  );

  const groups = new Map();
  for (const o of occurrences) {
    if (!o || !o.date) continue;
    const neighborhood = normalize(o.neighborhood);
    const city = normalize(o.city);
    const state = normalize(o.state);
    // Sem bairro, não dá pra ter baseline com a granularidade que a UI
    // usa hoje. Cidade sem bairro vira o seu próprio grupo só se quiser
    // expor cards de cidade — por ora, ignora.
    if (!neighborhood) continue;
    const key = regionKey({ state, city, neighborhood });
    let g = groups.get(key);
    if (!g) {
      g = {
        neighborhood,
        city,
        state,
        items: [],
        reasonCounts: new Map(),
      };
      groups.set(key, g);
    }
    g.items.push(o.date);
    const reason = o.mainReason || "outros";
    g.reasonCounts.set(reason, (g.reasonCounts.get(reason) || 0) + 1);
  }

  const result = {};
  for (const [key, g] of groups.entries()) {
    const total = g.items.length;
    const weeklyAverage = total === 0 ? 0 : (total / windowDays) * 7;
    const recentWeekCount = g.items.reduce(
      (n, d) => n + (d >= recentCutoff ? 1 : 0),
      0,
    );

    let trend;
    if (total < MIN_OCCURRENCES_FOR_TREND) {
      trend = "insufficient_data";
    } else if (weeklyAverage === 0) {
      trend = "stable";
    } else if (recentWeekCount >= weeklyAverage * TREND_UP_THRESHOLD) {
      trend = "up";
    } else if (recentWeekCount <= weeklyAverage * TREND_DOWN_THRESHOLD) {
      trend = "down";
    } else {
      trend = "stable";
    }

    const topReasons = Array.from(g.reasonCounts.entries())
      .sort((a, b) => b[1] - a[1])
      .slice(0, MAX_REASONS)
      .map(([reason, count]) => ({ reason, count }));

    result[key] = {
      neighborhood: g.neighborhood,
      city: g.city,
      state: g.state,
      totalOccurrences: total,
      weeklyAverage: round2(weeklyAverage),
      recentWeekCount,
      trend,
      topReasons,
      windowDays,
      recentWindowDays,
    };
  }
  return result;
}

/**
 * Chave de região estável. Lowercase, separadores fixos, fallback "_"
 * pra ausências. Casa com o que o cliente vai pedir (slug do bairro).
 */
function regionKey({ state, city, neighborhood }) {
  const slug = (s) =>
    (s || "_")
      .toLowerCase()
      .normalize("NFD")
      .replace(/[̀-ͯ]/g, "")
      .replace(/[^a-z0-9]+/g, "-")
      .replace(/^-|-$/g, "") || "_";
  return `${slug(state)}__${slug(city)}__${slug(neighborhood)}`;
}

function normalize(s) {
  if (s == null) return null;
  const trimmed = String(s).trim();
  return trimmed.length === 0 ? null : trimmed;
}

function round2(n) {
  return Math.round(n * 100) / 100;
}

exports._internal = { aggregateBaseline, regionKey };
