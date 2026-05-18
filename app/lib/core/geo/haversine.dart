library;

import 'dart:math' as math;

/// Distância aproximada em km entre dois pontos em coordenadas geográficas
/// (Haversine, raio médio da Terra = 6371 km).
///
/// Aceita lat/lng como [double] pra ficar livre de dependência de
/// pacotes de mapa — pode ser usado em testes puros e em qualquer camada.
double haversineKm(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371.0;
  final dLat = _toRad(lat2 - lat1);
  final dLng = _toRad(lng2 - lng1);
  final rLat1 = _toRad(lat1);
  final rLat2 = _toRad(lat2);
  final h = (1 - math.cos(dLat)) / 2 +
      math.cos(rLat1) * math.cos(rLat2) * (1 - math.cos(dLng)) / 2;
  return 2 * r * math.asin(math.sqrt(h));
}

double _toRad(double d) => d * math.pi / 180.0;
