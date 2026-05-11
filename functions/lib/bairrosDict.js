"use strict";

/**
 * Dicionário local de bairros de Salvador pra geocodificação offline.
 *
 * Origem: bairros_salvador.json (152 bairros via OpenStreetMap Overpass).
 * Estratégia: match exato → fuzzy (Levenshtein) → null.
 *
 * Evita Google Geocoding API pra ~85% dos casos, reduz custo e latência.
 */

const path = require("path");
const fs = require("fs");

let bairrosCache = null;

function load() {
  if (bairrosCache) return bairrosCache;
  const file = path.join(__dirname, "..", "bairros_salvador.json");
  const raw = fs.readFileSync(file, "utf-8");
  const data = JSON.parse(raw);
  bairrosCache = Object.entries(data).map(([name, v]) => ({
    name,
    nameNorm: stripAccents(name.toLowerCase()),
    lat: v.lat,
    lng: v.lng,
  }));
  return bairrosCache;
}

function stripAccents(s) {
  return s.normalize("NFD").replace(/[̀-ͯ]/g, "");
}

/**
 * Levenshtein simples — suficiente pro tamanho dos nomes (<= 30 chars).
 * Não otimizado, mas O(n*m) com n, m pequenos não é problema.
 */
function levenshtein(a, b) {
  if (a === b) return 0;
  if (!a.length) return b.length;
  if (!b.length) return a.length;
  const dp = Array(a.length + 1);
  for (let i = 0; i <= a.length; i++) dp[i] = [i];
  for (let j = 1; j <= b.length; j++) dp[0][j] = j;
  for (let i = 1; i <= a.length; i++) {
    for (let j = 1; j <= b.length; j++) {
      const cost = a[i - 1] === b[j - 1] ? 0 : 1;
      dp[i][j] = Math.min(
        dp[i - 1][j] + 1,
        dp[i][j - 1] + 1,
        dp[i - 1][j - 1] + cost
      );
    }
  }
  return dp[a.length][b.length];
}

/**
 * Resolve um nome de bairro pra {lat, lng, matched, method}.
 * Retorna null se não confiável.
 */
function resolveBairro(input) {
  if (!input || typeof input !== "string") return null;
  const query = stripAccents(input.trim().toLowerCase());
  if (query.length < 3) return null;

  const bairros = load();

  // 1) Match exato
  const exact = bairros.find((b) => b.nameNorm === query);
  if (exact) {
    return {
      lat: exact.lat,
      lng: exact.lng,
      matched: exact.name,
      method: "exact",
      score: 1.0,
    };
  }

  // 2) Substring match (query contida no nome ou nome contido na query)
  const sub = bairros.find(
    (b) => b.nameNorm.includes(query) || query.includes(b.nameNorm)
  );
  if (sub) {
    return {
      lat: sub.lat,
      lng: sub.lng,
      matched: sub.name,
      method: "substring",
      score: 0.9,
    };
  }

  // 3) Fuzzy via Levenshtein — threshold proporcional ao tamanho
  let best = null;
  let bestDistance = Infinity;
  for (const b of bairros) {
    const d = levenshtein(query, b.nameNorm);
    if (d < bestDistance) {
      bestDistance = d;
      best = b;
    }
  }
  if (!best) return null;

  const threshold = Math.max(2, Math.floor(query.length * 0.25));
  if (bestDistance > threshold) return null;

  return {
    lat: best.lat,
    lng: best.lng,
    matched: best.name,
    method: "fuzzy",
    score: 1.0 - bestDistance / query.length,
  };
}

module.exports = { resolveBairro };
