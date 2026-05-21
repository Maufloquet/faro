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
  resolveCityKey,
  getCentroid,
  stateForCity,
};
