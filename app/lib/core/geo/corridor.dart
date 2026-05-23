library;

import 'dart:math' as math;

import 'haversine.dart';

/// Distância perpendicular aproximada (em km) de um ponto até o
/// segmento (a→b), em coordenadas geográficas.
///
/// Implementação: projeta tudo num plano local equirretangular usando
/// a latitude média como referência. Pra distâncias < 50 km em
/// latitudes baixas (Salvador ~12°S), o erro fica abaixo de 0.5%. É o
/// suficiente pro corredor de rota (raio típico 500m).
///
/// Se o ponto cai antes de A ou depois de B (projeção fora do
/// segmento), retorna a distância pro endpoint mais próximo — assim
/// um ponto longe demais nunca fica dentro do corredor por erro de
/// extrapolação da reta.
double distanceToSegmentKm({
  required double pointLat,
  required double pointLng,
  required double aLat,
  required double aLng,
  required double bLat,
  required double bLng,
}) {
  // Conversão pra plano local em km, usando latitude média como ref.
  // 1° lat ≈ 111.32 km (constante).
  // 1° lng ≈ 111.32 * cos(latRef) km.
  final latRef = (aLat + bLat) / 2;
  final cosRef = math.cos(latRef * math.pi / 180.0);
  const kmPerDegLat = 111.32;
  final kmPerDegLng = kmPerDegLat * cosRef;

  double project(double lng, double lat) {
    return lng; // só pra clareza — usamos x e y direto
  }
  // (a,b) → cartesiano
  final ax = aLng * kmPerDegLng;
  final ay = aLat * kmPerDegLat;
  final bx = bLng * kmPerDegLng;
  final by = bLat * kmPerDegLat;
  final px = pointLng * kmPerDegLng;
  final py = pointLat * kmPerDegLat;
  // ignorando warning unused — _ = ...
  // (variável project mantida pra clareza de leitura)
  // ignore: unused_local_variable
  final _ = project;

  final dx = bx - ax;
  final dy = by - ay;
  final segLen2 = dx * dx + dy * dy;
  if (segLen2 == 0) {
    // a == b — distância ponto-ponto via Haversine pra manter precisão
    return haversineKm(pointLat, pointLng, aLat, aLng);
  }

  // Parâmetro t da projeção: 0 = A, 1 = B
  final t = ((px - ax) * dx + (py - ay) * dy) / segLen2;
  if (t <= 0) {
    return haversineKm(pointLat, pointLng, aLat, aLng);
  }
  if (t >= 1) {
    return haversineKm(pointLat, pointLng, bLat, bLng);
  }

  // Projeção dentro do segmento — distância perpendicular
  final projX = ax + t * dx;
  final projY = ay + t * dy;
  final dXkm = px - projX;
  final dYkm = py - projY;
  return math.sqrt(dXkm * dXkm + dYkm * dYkm);
}

/// Caixa envolvente (bbox) do corredor formado pelo segmento (a→b)
/// com `bufferKm` de margem em volta. Útil pra pre-filtrar occurrences
/// antes de chamar `distanceToSegmentKm` (mais barato fazer comparação
/// retangular de coordenadas que cálculo da distância pra cada).
///
/// Retorna `(southLat, westLng, northLat, eastLng)`.
({double southLat, double westLng, double northLat, double eastLng})
    corridorBbox({
  required double aLat,
  required double aLng,
  required double bLat,
  required double bLng,
  required double bufferKm,
}) {
  final south = math.min(aLat, bLat);
  final north = math.max(aLat, bLat);
  final west = math.min(aLng, bLng);
  final east = math.max(aLng, bLng);

  const kmPerDegLat = 111.32;
  final cosRef = math.cos(((south + north) / 2) * math.pi / 180.0).abs();
  final kmPerDegLng = kmPerDegLat * (cosRef == 0 ? 1 : cosRef);

  final latPad = bufferKm / kmPerDegLat;
  final lngPad = bufferKm / kmPerDegLng;

  return (
    southLat: south - latPad,
    westLng: west - lngPad,
    northLat: north + latPad,
    eastLng: east + lngPad,
  );
}

/// True se o ponto (lat,lng) cai dentro do corredor de raio `bufferKm`
/// em torno do segmento (a→b). Fast-path via bbox antes do cálculo
/// preciso.
bool pointInCorridor({
  required double pointLat,
  required double pointLng,
  required double aLat,
  required double aLng,
  required double bLat,
  required double bLng,
  required double bufferKm,
}) {
  final bbox = corridorBbox(
    aLat: aLat,
    aLng: aLng,
    bLat: bLat,
    bLng: bLng,
    bufferKm: bufferKm,
  );
  if (pointLat < bbox.southLat ||
      pointLat > bbox.northLat ||
      pointLng < bbox.westLng ||
      pointLng > bbox.eastLng) {
    return false;
  }
  final d = distanceToSegmentKm(
    pointLat: pointLat,
    pointLng: pointLng,
    aLat: aLat,
    aLng: aLng,
    bLat: bLat,
    bLng: bLng,
  );
  return d <= bufferKm;
}
