import 'package:flutter_test/flutter_test.dart';
import 'package:projeto_seg/core/geo/haversine.dart';

void main() {
  group('haversineKm', () {
    test('mesmo ponto retorna 0', () {
      expect(haversineKm(-12.9714, -38.5014, -12.9714, -38.5014), closeTo(0, 1e-9));
    });

    test('simétrica em relação à ordem dos pontos', () {
      final a = haversineKm(-12.9714, -38.5014, -12.8895, -38.3260);
      final b = haversineKm(-12.8895, -38.3260, -12.9714, -38.5014);
      expect(a, closeTo(b, 1e-9));
    });

    test('Salvador centro → Lauro de Freitas ≈ 21 km', () {
      // Pelourinho (-12.9714, -38.5014) → Lauro de Freitas (-12.8895, -38.3260).
      // Valor de referência calculado externamente: ~21.0 km.
      final d = haversineKm(-12.9714, -38.5014, -12.8895, -38.3260);
      expect(d, closeTo(21.0, 1.0));
    });

    test('um grau de latitude no equador ≈ 111 km', () {
      final d = haversineKm(0, 0, 1, 0);
      expect(d, closeTo(111.0, 1.0));
    });

    test('pontos diametralmente opostos ≈ meia circunferência (20015 km)', () {
      // Raio 6371 km → π·r ≈ 20015 km.
      final d = haversineKm(0, 0, 0, 180);
      expect(d, closeTo(20015.0, 5.0));
    });
  });
}
