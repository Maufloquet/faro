"use strict";

/**
 * Chave canônica de evento — usada pra deduplicar a mesma ocorrência quando
 * ela chega por fontes diferentes (A Tarde + iBahia + Fogo Cruzado).
 *
 * Estratégia: a chave é source-agnostic. Composta por (cidade, bairro, tipo)
 * todos normalizados (sem acento, lowercase, espaços virando underscore).
 * A janela temporal (±6h) é aplicada por quem faz a query — não entra na
 * chave porque a chave é estável e indexável.
 *
 * Sem bairro identificável (geocodeMethod=city-centroid), usamos o sentinel
 * "_centroid" pra que duas matérias com o mesmo tipo no mesmo dia caiam
 * juntas em vez de cada uma virar doc próprio.
 *
 * Retorna null se faltar city OU mainReason — sem esses dois, o dedupe
 * juntaria coisas distintas (ex.: "qualquer crime hoje em qualquer lugar").
 */

function stripAccents(s) {
  return s.normalize("NFD").replace(/[̀-ͯ]/g, "");
}

function slug(s) {
  return stripAccents(String(s || "").trim().toLowerCase())
    .replace(/\s+/g, "_")
    .replace(/[^a-z0-9_]/g, "");
}

/**
 * @param {object} input
 * @param {string|null} input.city          ex.: "Salvador"
 * @param {string|null} input.neighborhood  ex.: "Pirajá" ou null
 * @param {string|null} input.mainReason    ex.: "Tiroteio"
 * @param {string|null} [input.geocodeMethod] usado pra detectar city-centroid
 * @returns {string|null}
 */
function buildEventKey({ city, neighborhood, mainReason, geocodeMethod } = {}) {
  const cityS = slug(city);
  const typeS = slug(mainReason);
  if (!cityS || !typeS) return null;

  let neighS;
  if (geocodeMethod === "city-centroid" || !neighborhood) {
    neighS = "_centroid";
  } else {
    neighS = slug(neighborhood) || "_centroid";
  }

  return `${cityS}|${neighS}|${typeS}`;
}

module.exports = { buildEventKey };
module.exports._internal = { slug };
