import 'package:flutter_test/flutter_test.dart';
import 'package:projeto_seg/services/safe_arrival_service.dart';

void main() {
  group('arrivalShareMessage', () {
    final at = DateTime(2026, 5, 26, 20, 5);

    test('sem posição: só a mensagem + hora', () {
      final msg = arrivalShareMessage(now: at);
      expect(msg, 'Cheguei bem — 20:05.');
      expect(msg.contains('http'), isFalse);
    });

    test('com posição: inclui link de mapa', () {
      final msg = arrivalShareMessage(now: at, lat: -12.97, lng: -38.5);
      expect(msg, contains('20:05'));
      expect(msg, contains('https://maps.google.com/?q=-12.97,-38.5'));
    });

    test('hora com zero à esquerda', () {
      final msg = arrivalShareMessage(now: DateTime(2026, 5, 26, 9, 3));
      expect(msg, contains('09:03'));
    });
  });
}
