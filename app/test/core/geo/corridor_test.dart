import 'package:flutter_test/flutter_test.dart';
import 'package:projeto_seg/core/geo/corridor.dart';

void main() {
  group('distanceToSegmentKm', () {
    test('ponto sobre o segmento retorna ~0', () {
      // Linha Pituba (Av Paulo VI ~ -12.997, -38.461) até Iguatemi
      // (~ -12.978, -38.460). Ponto no meio.
      final d = distanceToSegmentKm(
        pointLat: -12.9875,
        pointLng: -38.4605,
        aLat: -12.997,
        aLng: -38.461,
        bLat: -12.978,
        bLng: -38.460,
      );
      expect(d, lessThan(0.05));
    });

    test('ponto perpendicular a 500m do segmento retorna ~0.5km', () {
      // Segmento curto leste-oeste em Salvador
      final d = distanceToSegmentKm(
        pointLat: -12.985, // 500m ao sul da linha em -12.980
        pointLng: -38.470,
        aLat: -12.980,
        aLng: -38.480,
        bLat: -12.980,
        bLng: -38.460,
      );
      // ~500-600m de tolerância (projeção equirretangular tem pequeno erro)
      expect(d, greaterThan(0.4));
      expect(d, lessThan(0.7));
    });

    test('ponto antes do A volta pra distância ponto-A', () {
      // Segmento de A=(-13, -38.5) a B=(-12.95, -38.5). Ponto bem ao norte de A.
      final d = distanceToSegmentKm(
        pointLat: -13.020, // 0.02° = ~2.2km ao sul de A
        pointLng: -38.500,
        aLat: -13.000,
        aLng: -38.500,
        bLat: -12.950,
        bLng: -38.500,
      );
      expect(d, greaterThan(2.0));
      expect(d, lessThan(2.5));
    });

    test('A == B cai pra haversine ponto-ponto', () {
      final d = distanceToSegmentKm(
        pointLat: -12.99,
        pointLng: -38.50,
        aLat: -13.00,
        aLng: -38.50,
        bLat: -13.00,
        bLng: -38.50,
      );
      // ~1.1km
      expect(d, greaterThan(1.0));
      expect(d, lessThan(1.3));
    });
  });

  group('pointInCorridor', () {
    test('ponto a 200m do segmento entra no corredor de 500m', () {
      final inCorridor = pointInCorridor(
        pointLat: -12.982, // ~200m ao sul da linha em -12.980
        pointLng: -38.470,
        aLat: -12.980,
        aLng: -38.480,
        bLat: -12.980,
        bLng: -38.460,
        bufferKm: 0.5,
      );
      expect(inCorridor, isTrue);
    });

    test('ponto a 2km do segmento NÃO entra no corredor de 500m', () {
      final inCorridor = pointInCorridor(
        pointLat: -13.000,
        pointLng: -38.470,
        aLat: -12.980,
        aLng: -38.480,
        bLat: -12.980,
        bLng: -38.460,
        bufferKm: 0.5,
      );
      expect(inCorridor, isFalse);
    });

    test('ponto fora da bbox não entra no corredor (fast-path)', () {
      // Ponto a 100km de distância — não deve nem chegar ao cálculo
      // preciso. Só confirma que a função não derrapa pra um lugar
      // bem distante.
      final inCorridor = pointInCorridor(
        pointLat: -25.0,
        pointLng: -50.0,
        aLat: -12.980,
        aLng: -38.480,
        bLat: -12.980,
        bLng: -38.460,
        bufferKm: 0.5,
      );
      expect(inCorridor, isFalse);
    });
  });
}
