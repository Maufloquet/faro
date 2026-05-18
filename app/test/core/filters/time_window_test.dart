import 'package:flutter_test/flutter_test.dart';
import 'package:projeto_seg/core/filters/time_window.dart';

void main() {
  group('TimeWindow.includes', () {
    test('hoje cobre últimas 24h', () {
      final now = DateTime.now();
      expect(TimeWindow.hoje.includes(now), isTrue);
      expect(TimeWindow.hoje.includes(now.subtract(const Duration(hours: 23))), isTrue);
      expect(TimeWindow.hoje.includes(now.subtract(const Duration(hours: 25))), isFalse);
    });

    test('semana cobre 7 dias', () {
      final now = DateTime.now();
      expect(TimeWindow.semana.includes(now.subtract(const Duration(days: 6))), isTrue);
      expect(TimeWindow.semana.includes(now.subtract(const Duration(days: 8))), isFalse);
    });

    test('mes cobre 30 dias', () {
      final now = DateTime.now();
      expect(TimeWindow.mes.includes(now.subtract(const Duration(days: 29))), isTrue);
      expect(TimeWindow.mes.includes(now.subtract(const Duration(days: 31))), isFalse);
    });

    test('tudo aceita qualquer data, inclusive antiga', () {
      expect(TimeWindow.tudo.includes(DateTime(2020)), isTrue);
      expect(TimeWindow.tudo.includes(DateTime.now()), isTrue);
    });

    test('data no futuro ainda é incluída em janelas finitas (diff é negativo)', () {
      // Quirk documentado: data futura cai em todas as janelas porque
      // diff < duration. Se virar bug real, mudar pra abs() no includes.
      final future = DateTime.now().add(const Duration(days: 1));
      expect(TimeWindow.hoje.includes(future), isTrue);
    });
  });
}
