"use strict";

/**
 * Dicionário local de bairros para cidades cobertas pelo Faro
 * (Salvador + RMS) — usado para geocodificação offline.
 *
 * Estratégia em camadas:
 * 1. Match no dicionário da cidade indicada (exato → substring → fuzzy)
 * 2. Match em qualquer cidade (em caso de cidade ambígua)
 * 3. Centroide da cidade como fallback (quando notícia menciona cidade
 *    sem bairro identificável)
 * 4. null (descartar)
 */

const path = require("path");
const fs = require("fs");

const { resolveCityKey, getCentroid } = require("./cityCentroids");

const CITY_FILES = {
  salvador: "bairros_salvador.json",
  camacari: "bairros_camacari.json",
  lauro_de_freitas: "bairros_lauro_de_freitas.json",
  simoes_filho: "bairros_simoes_filho.json",
};

let bairrosByCity = null;

function load() {
  if (bairrosByCity) return bairrosByCity;
  bairrosByCity = {};
  for (const [cityKey, filename] of Object.entries(CITY_FILES)) {
    const file = path.join(__dirname, "..", filename);
    if (!fs.existsSync(file)) {
      bairrosByCity[cityKey] = [];
      continue;
    }
    try {
      const raw = fs.readFileSync(file, "utf-8");
      const data = JSON.parse(raw);
      bairrosByCity[cityKey] = Object.entries(data).map(([name, v]) => ({
        name,
        nameNorm: stripAccents(name.toLowerCase()),
        lat: v.lat,
        lng: v.lng,
        city: cityKey,
      }));
    } catch (e) {
      bairrosByCity[cityKey] = [];
    }
  }
  return bairrosByCity;
}

function stripAccents(s) {
  return s.normalize("NFD").replace(/[̀-ͯ]/g, "");
}

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

function matchInDict(query, dict) {
  if (!query || dict.length === 0) return null;

  // 1) Match exato
  const exact = dict.find((b) => b.nameNorm === query);
  if (exact) {
    return { ...exact, method: "exact", score: 1.0 };
  }

  // 2) Substring
  const sub = dict.find(
    (b) => b.nameNorm.includes(query) || query.includes(b.nameNorm)
  );
  if (sub) {
    return { ...sub, method: "substring", score: 0.9 };
  }

  // 3) Fuzzy Levenshtein — threshold proporcional ao tamanho
  let best = null;
  let bestDistance = Infinity;
  for (const b of dict) {
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
    ...best,
    method: "fuzzy",
    score: 1.0 - bestDistance / query.length,
  };
}

/**
 * Resolve um nome de bairro (opcional) + nome de cidade em coordenadas.
 *
 * @param {string|null} neighborhood - nome do bairro (pode ser null)
 * @param {string|null} cityName - nome da cidade
 * @returns {{lat, lng, matched, method, cityKey} | null}
 */
function resolveBairro(neighborhood, cityName) {
  const dicts = load();
  const cityKey = resolveCityKey(cityName);

  // Se temos bairro: tenta matchar no dicionário da cidade primeiro,
  // depois em qualquer dicionário se cidade for ambígua.
  if (neighborhood && typeof neighborhood === "string") {
    const query = stripAccents(neighborhood.trim().toLowerCase());
    if (query.length >= 3) {
      // Prioridade: dict da cidade indicada
      if (cityKey && dicts[cityKey]) {
        const m = matchInDict(query, dicts[cityKey]);
        if (m) {
          return {
            lat: m.lat,
            lng: m.lng,
            matched: m.name,
            method: m.method,
            cityKey: m.city,
          };
        }
      }
      // Fallback: tenta em todos os dicts (caso o LLM tenha extraído
      // bairro certo mas cidade errada/ausente)
      for (const [key, dict] of Object.entries(dicts)) {
        if (key === cityKey) continue;
        const m = matchInDict(query, dict);
        if (m) {
          return {
            lat: m.lat,
            lng: m.lng,
            matched: m.name,
            method: m.method,
            cityKey: m.city,
          };
        }
      }
    }
  }

  // Sem bairro identificável → cai pro centroide da cidade
  if (cityKey) {
    const centroid = getCentroid(cityKey);
    if (centroid) {
      return {
        lat: centroid.lat,
        lng: centroid.lng,
        matched: centroid.name,
        method: "city-centroid",
        cityKey,
      };
    }
  }

  return null;
}

module.exports = { resolveBairro };
