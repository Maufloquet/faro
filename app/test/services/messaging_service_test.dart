import 'package:flutter_test/flutter_test.dart';
import 'package:projeto_seg/services/messaging_service.dart';

void main() {
  group('geohash5Of', () {
    test('retorna sempre 5 caracteres', () {
      expect(geohash5Of(-12.9714, -38.5014).length, 5);
      expect(geohash5Of(0, 0).length, 5);
      expect(geohash5Of(89.999, 179.999).length, 5);
      expect(geohash5Of(-89.999, -179.999).length, 5);
    });

    test('usa apenas chars do alfabeto base32 (geohash)', () {
      const valid = '0123456789bcdefghjkmnpqrstuvwxyz';
      final hash = geohash5Of(-12.9714, -38.5014);
      for (final c in hash.split('')) {
        expect(valid.contains(c), isTrue, reason: 'char "$c" fora do alfabeto');
      }
    });

    test('é determinístico: mesmas coords = mesmo hash', () {
      final a = geohash5Of(-12.9714, -38.5014);
      final b = geohash5Of(-12.9714, -38.5014);
      expect(a, b);
    });

    test('pontos próximos compartilham prefixo', () {
      final salvadorCentro = geohash5Of(-12.9714, -38.5014);
      final salvadorPerto = geohash5Of(-12.9720, -38.5020); // ~60m de distância
      // Pelo menos 3 chars iniciais devem coincidir (precisão de ~150km
      // já é compartilhada com tudo na Bahia).
      expect(
        salvadorPerto.substring(0, 3),
        salvadorCentro.substring(0, 3),
      );
    });

    test('pontos muito distantes divergem cedo no prefixo', () {
      final salvador = geohash5Of(-12.9714, -38.5014);
      final tokyo = geohash5Of(35.6762, 139.6503);
      expect(salvador[0], isNot(equals(tokyo[0])));
    });
  });
}
