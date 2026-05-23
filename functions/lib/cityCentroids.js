"use strict";

/**
 * Centroides aproximados das cidades cobertas pela Camada 2 (notícias).
 *
 * Cada entry tem `state` (sigla UF) — usado pelo newsIngest pra rotular
 * a ocorrência sem hardcode. Cobertura cresce conforme adicionamos
 * sources por região.
 *
 * Trade-off editorial: marker no centroide é menos preciso que num
 * bairro real, mas melhor do que perder a ocorrência. UX no app sinaliza
 * imprecisão com círculo de incerteza (`Occurrence.isCityCentroid`).
 */

const CITY_CENTROIDS = {
  // ─── RMS (Bahia) — cobertura plena com bairros ───
  salvador: {
    name: "Salvador",
    state: "BA",
    lat: -12.9714,
    lng: -38.5014,
    aliases: ["salvador"],
  },
  camacari: {
    name: "Camaçari",
    state: "BA",
    lat: -12.6993,
    lng: -38.3261,
    aliases: ["camaçari", "camacari"],
  },
  lauro_de_freitas: {
    name: "Lauro de Freitas",
    state: "BA",
    lat: -12.8920,
    lng: -38.3270,
    aliases: ["lauro de freitas", "lauro"],
  },
  simoes_filho: {
    name: "Simões Filho",
    state: "BA",
    lat: -12.7831,
    lng: -38.4042,
    aliases: ["simões filho", "simoes filho"],
  },

  // ─── Região Metropolitana do Rio de Janeiro ───
  rio_de_janeiro: {
    name: "Rio de Janeiro",
    state: "RJ",
    lat: -22.9068,
    lng: -43.1729,
    aliases: ["rio de janeiro"],
  },
  niteroi: {
    name: "Niterói",
    state: "RJ",
    lat: -22.8839,
    lng: -43.1036,
    aliases: ["niterói", "niteroi"],
  },
  sao_goncalo: {
    name: "São Gonçalo",
    state: "RJ",
    lat: -22.8268,
    lng: -43.0539,
    aliases: ["são gonçalo", "sao goncalo"],
  },
  duque_de_caxias: {
    name: "Duque de Caxias",
    state: "RJ",
    lat: -22.7858,
    lng: -43.3128,
    aliases: ["duque de caxias"],
  },
  nova_iguacu: {
    name: "Nova Iguaçu",
    state: "RJ",
    lat: -22.7556,
    lng: -43.4604,
    aliases: ["nova iguaçu", "nova iguacu"],
  },

  // ─── Região Metropolitana de Recife (Pernambuco) ───
  recife: {
    name: "Recife",
    state: "PE",
    lat: -8.0476,
    lng: -34.8770,
    aliases: ["recife"],
  },
  olinda: {
    name: "Olinda",
    state: "PE",
    lat: -8.0089,
    lng: -34.8553,
    aliases: ["olinda"],
  },
  jaboatao_dos_guararapes: {
    name: "Jaboatão dos Guararapes",
    state: "PE",
    lat: -8.1130,
    lng: -35.0148,
    aliases: ["jaboatão dos guararapes", "jaboatao dos guararapes"],
  },
  paulista: {
    name: "Paulista",
    state: "PE",
    lat: -7.9408,
    lng: -34.8728,
    aliases: ["paulista pernambuco", "paulista pe"],
  },

  // ─── Região Metropolitana de São Paulo ───
  sao_paulo: {
    name: "São Paulo",
    state: "SP",
    lat: -23.5505,
    lng: -46.6333,
    aliases: ["são paulo", "sao paulo"],
  },
  guarulhos: {
    name: "Guarulhos",
    state: "SP",
    lat: -23.4538,
    lng: -46.5333,
    aliases: ["guarulhos"],
  },
  sao_bernardo_do_campo: {
    name: "São Bernardo do Campo",
    state: "SP",
    lat: -23.6914,
    lng: -46.5646,
    aliases: ["são bernardo do campo", "sao bernardo do campo"],
  },
  santo_andre: {
    name: "Santo André",
    state: "SP",
    lat: -23.6633,
    lng: -46.5306,
    aliases: ["santo andré", "santo andre"],
  },
  osasco: {
    name: "Osasco",
    state: "SP",
    lat: -23.5325,
    lng: -46.7917,
    aliases: ["osasco"],
  },
};

function stripAccents(s) {
  return s.normalize("NFD").replace(/[̀-ͯ]/g, "");
}

/**
 * Whitelist explícita das cidades ingeridas no MVP. Source of truth pro
 * `newsIngest` decidir se aceita ou descarta o item — não acoplar aos
 * keys de CITY_CENTROIDS porque incluímos RJ/PE/SP nele pra ter o
 * `state` resolvido sem hardcode, mas hoje a Camada 2 só ingere BA.
 *
 * Quando o app ganhar selector de estado na UI, expandir aqui — e
 * idealmente passar pra config por flag/env, não código.
 */
const COVERED_CITY_KEYS = new Set([
  "salvador",
  "camacari",
  "lauro_de_freitas",
  "simoes_filho",
]);

function isCoveredCity(cityKey) {
  return COVERED_CITY_KEYS.has(cityKey);
}

/**
 * Retorna a key da cidade (slug) se o nome bater, ou null.
 *
 * Match por palavra inteira (com fronteira não-alfanumérica) em vez de
 * substring crua — evita que alias curto como "lauro" matche "Lauro
 * Soares" ou "Sao Paulo" matche "Sao Paulo de Olivença". A entrada
 * vinda do LLM costuma ter exatamente o nome do município, então
 * `\b` cobre tudo o que importa sem perder match legítimo.
 */
function resolveCityKey(rawCity) {
  if (!rawCity) return null;
  const q = stripAccents(rawCity.trim().toLowerCase());
  for (const [key, city] of Object.entries(CITY_CENTROIDS)) {
    for (const alias of city.aliases) {
      const aliasNorm = stripAccents(alias);
      const pattern = new RegExp(`(^|[^a-z0-9])${escapeRegex(aliasNorm)}([^a-z0-9]|$)`);
      if (pattern.test(q)) return key;
    }
  }
  return null;
}

function escapeRegex(s) {
  return s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

function getCentroid(cityKey) {
  return CITY_CENTROIDS[cityKey] || null;
}

/**
 * Sigla UF associada à cidade. Fallback null se cidade desconhecida.
 * Usado pelo newsIngest pra rotular ocorrências sem hardcode de estado.
 */
function stateForCity(cityKey) {
  const c = CITY_CENTROIDS[cityKey];
  return c ? c.state : null;
}

module.exports = {
  CITY_CENTROIDS,
  COVERED_CITY_KEYS,
  isCoveredCity,
  resolveCityKey,
  getCentroid,
  stateForCity,
};
