"use strict";

/**
 * Centroides aproximados das cidades da RMS — usados como fallback
 * quando uma notícia menciona a cidade mas sem bairro específico (ou
 * com bairro que não bate no dicionário local).
 *
 * Trade-off editorial: marker no centroide é menos preciso que num
 * bairro real, mas melhor do que perder a ocorrência. UX no app deve
 * deixar claro que esse pin representa "algo aconteceu nessa cidade",
 * não local exato.
 */

const CITY_CENTROIDS = {
  salvador: {
    name: "Salvador",
    lat: -12.9714,
    lng: -38.5014,
    aliases: ["salvador"],
  },
  camacari: {
    name: "Camaçari",
    lat: -12.6993,
    lng: -38.3261,
    aliases: ["camaçari", "camacari"],
  },
  lauro_de_freitas: {
    name: "Lauro de Freitas",
    lat: -12.8920,
    lng: -38.3270,
    aliases: ["lauro de freitas", "lauro"],
  },
  simoes_filho: {
    name: "Simões Filho",
    lat: -12.7831,
    lng: -38.4042,
    aliases: ["simões filho", "simoes filho"],
  },
};

function stripAccents(s) {
  return s.normalize("NFD").replace(/[̀-ͯ]/g, "");
}

/** Retorna a key da cidade (slug) se o nome bater, ou null. */
function resolveCityKey(rawCity) {
  if (!rawCity) return null;
  const q = stripAccents(rawCity.trim().toLowerCase());
  for (const [key, city] of Object.entries(CITY_CENTROIDS)) {
    for (const alias of city.aliases) {
      if (q.includes(stripAccents(alias))) return key;
    }
  }
  return null;
}

function getCentroid(cityKey) {
  return CITY_CENTROIDS[cityKey] || null;
}

module.exports = { CITY_CENTROIDS, resolveCityKey, getCentroid };
