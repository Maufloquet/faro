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

/**
 * Comprimento mínimo de nome de bairro pra ser elegível a match via
 * substring. Sem isso, nomes curtos como "Lapa" (4 chars), "Roma" (4),
 * "Barra" (5) engolem qualquer query mais longa que os contenha
 * ("Lapinha de Cima" → Lapa, "Barra do Pojuca" → Barra de Salvador).
 */
const SUBSTRING_MIN_LEN = 6;

/**
 * @param {string} query nome de bairro normalizado (sem acento, lowercase)
 * @param {Array} dict lista de bairros { name, nameNorm, lat, lng, city }
 * @param {object} opts
 * @param {boolean} opts.exactOnly se true, só aceita match exato (sem
 *   substring nem fuzzy). Usado quando vamos buscar em dicts de cidades
 *   diferentes daquela indicada pelo LLM — onde substring/fuzzy ficam
 *   perigosos demais.
 */
function matchInDict(query, dict, opts = {}) {
  if (!query || dict.length === 0) return null;
  const exactOnly = opts.exactOnly === true;

  // 1) Match exato — sempre primeiro, único caminho confiável.
  const exact = dict.find((b) => b.nameNorm === query);
  if (exact) {
    return { ...exact, method: "exact", score: 1.0 };
  }

  if (exactOnly) return null;

  // 2) Substring — só vale pra nameNorm >= SUBSTRING_MIN_LEN, evitando
  //    falsos positivos com nomes curtos absorvendo queries longas.
  const sub = dict.find((b) => {
    if (b.nameNorm.length < SUBSTRING_MIN_LEN) return false;
    return b.nameNorm.includes(query) || query.includes(b.nameNorm);
  });
  if (sub) {
    return { ...sub, method: "substring", score: 0.9 };
  }

  // 3) Fuzzy Levenshtein — threshold proporcional ao tamanho.
  //    Mantém restrição implícita: query curta (< 4) tem threshold 2,
  //    o que ainda assim impede match grosseiro.
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
      // Fallback inter-cidades: tenta nas outras cidades, mas **somente
      // match exato**. Substring/fuzzy aqui enviesa pra Salvador (primeiro
      // dict iterado) e vira fonte de erro sistemático. Se LLM extraiu
      // bairro real porém cidade errada/ausente, o nome exato basta;
      // qualquer ambiguidade é mais segura no centroide da cidade.
      for (const [key, dict] of Object.entries(dicts)) {
        if (key === cityKey) continue;
        const m = matchInDict(query, dict, { exactOnly: true });
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
