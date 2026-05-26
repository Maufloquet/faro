"use strict";

/**
 * Geometria de corredor de rota no servidor — porta fiel do
 * `app/lib/core/geo/corridor.dart`. Usada pelo scheduler `watchRoutes`
 * pra decidir se uma ocorrência caiu dentro do corredor de um trajeto
 * observado.
 *
 * Plano local equirretangular com latitude média como referência: erro
 * < 0.5% pra distâncias < 50 km em latitudes baixas (Salvador ~12°S),
 * suficiente pro corredor (raio típico 500 m).
 */

const KM_PER_DEG_LAT = 111.32;
const EARTH_KM = 6371;

function toRad(d) {
  return (d * Math.PI) / 180;
}

/** Distância ponto-a-ponto (km) — Haversine. */
function haversineKm(lat1, lng1, lat2, lng2) {
  const dLat = toRad(lat2 - lat1);
  const dLng = toRad(lng2 - lng1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) ** 2;
  return EARTH_KM * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

/**
 * Distância perpendicular aproximada (km) de um ponto ao segmento (a→b).
 * Se a projeção cai fora do segmento, devolve a distância pro endpoint
 * mais próximo (evita extrapolar a reta).
 */
function distanceToSegmentKm(pointLat, pointLng, aLat, aLng, bLat, bLng) {
  const latRef = (aLat + bLat) / 2;
  const cosRef = Math.cos(toRad(latRef));
  const kmPerDegLng = KM_PER_DEG_LAT * cosRef;

  const ax = aLng * kmPerDegLng;
  const ay = aLat * KM_PER_DEG_LAT;
  const bx = bLng * kmPerDegLng;
  const by = bLat * KM_PER_DEG_LAT;
  const px = pointLng * kmPerDegLng;
  const py = pointLat * KM_PER_DEG_LAT;

  const dx = bx - ax;
  const dy = by - ay;
  const segLen2 = dx * dx + dy * dy;
  if (segLen2 === 0) {
    return haversineKm(pointLat, pointLng, aLat, aLng);
  }

  const t = ((px - ax) * dx + (py - ay) * dy) / segLen2;
  if (t <= 0) return haversineKm(pointLat, pointLng, aLat, aLng);
  if (t >= 1) return haversineKm(pointLat, pointLng, bLat, bLng);

  const projX = ax + t * dx;
  const projY = ay + t * dy;
  const dXkm = px - projX;
  const dYkm = py - projY;
  return Math.sqrt(dXkm * dXkm + dYkm * dYkm);
}

/** Bbox do corredor (segmento + bufferKm de margem). */
function corridorBbox(aLat, aLng, bLat, bLng, bufferKm) {
  const south = Math.min(aLat, bLat);
  const north = Math.max(aLat, bLat);
  const west = Math.min(aLng, bLng);
  const east = Math.max(aLng, bLng);
  const cosRef = Math.abs(Math.cos(toRad((south + north) / 2)));
  const kmPerDegLng = KM_PER_DEG_LAT * (cosRef === 0 ? 1 : cosRef);
  const latPad = bufferKm / KM_PER_DEG_LAT;
  const lngPad = bufferKm / kmPerDegLng;
  return {
    southLat: south - latPad,
    westLng: west - lngPad,
    northLat: north + latPad,
    eastLng: east + lngPad,
  };
}

/** True se o ponto cai no corredor de raio bufferKm em torno de (a→b). */
function pointInCorridor(pointLat, pointLng, aLat, aLng, bLat, bLng, bufferKm) {
  const bbox = corridorBbox(aLat, aLng, bLat, bLng, bufferKm);
  if (
    pointLat < bbox.southLat ||
    pointLat > bbox.northLat ||
    pointLng < bbox.westLng ||
    pointLng > bbox.eastLng
  ) {
    return false;
  }
  return distanceToSegmentKm(pointLat, pointLng, aLat, aLng, bLat, bLng) <= bufferKm;
}

module.exports = {
  haversineKm,
  distanceToSegmentKm,
  corridorBbox,
  pointInCorridor,
};
