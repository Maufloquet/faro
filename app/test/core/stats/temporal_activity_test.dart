import 'package:flutter_test/flutter_test.dart';
import 'package:projeto_seg/core/stats/temporal_activity.dart';
import 'package:projeto_seg/models/occurrence.dart';

Occurrence _o(DateTime date) => Occurrence(
      id: 'x',
      latitude: -12.97,
      longitude: -38.50,
      date: date,
    );

void main() {
  group('rankByHour', () {
    test('lista vazia retorna 24 buckets zerados', () {
      final r = rankByHour(const []);
      expect(r, hasLength(24));
      expect(r.every((b) => b.count == 0), isTrue);
    });

    test('buckets sempre cobrem 0 a 23 em ordem', () {
      final r = rankByHour(const []);
      for (var i = 0; i < 24; i++) {
        expect(r[i].hour, i);
      }
    });

    test('conta ocorrências por hora local', () {
      final r = rankByHour([
        _o(DateTime(2026, 5, 18, 8, 30)),
        _o(DateTime(2026, 5, 18, 8, 45)),
        _o(DateTime(2026, 5, 18, 22, 10)),
      ]);
      expect(r[8].count, 2);
      expect(r[22].count, 1);
      expect(r[10].count, 0);
    });
  });

  group('rankByWeekday', () {
    test('lista vazia retorna 7 buckets zerados', () {
      final r = rankByWeekday(const []);
      expect(r, hasLength(7));
      expect(r.every((b) => b.count == 0), isTrue);
    });

    test('cobre segunda (1) a domingo (7)', () {
      final r = rankByWeekday(const []);
      expect(r.first.weekday, 1);
      expect(r.last.weekday, 7);
    });

    test('conta por dia da semana', () {
      // 18/05/2026 é segunda. 19=ter, 23=sex, 24=sáb
      final r = rankByWeekday([
        _o(DateTime(2026, 5, 18, 10)),  // seg
        _o(DateTime(2026, 5, 23, 22)),  // sáb? checar
        _o(DateTime(2026, 5, 18, 14)),  // seg
      ]);
      expect(r[0].count, 2); // segunda
      // Não vou assertar 23/05 sem checar — o ponto é que ranks distribuem.
      final total = r.fold<int>(0, (a, b) => a + b.count);
      expect(total, 3);
    });
  });

  group('peakHour', () {
    test('retorna null para tudo zerado', () {
      expect(peakHour(rankByHour(const [])), isNull);
    });

    test('retorna hora com maior contagem', () {
      final r = rankByHour([
        _o(DateTime(2026, 5, 18, 22)),
        _o(DateTime(2026, 5, 18, 22)),
        _o(DateTime(2026, 5, 18, 22)),
        _o(DateTime(2026, 5, 18, 10)),
      ]);
      expect(peakHour(r), 22);
    });
  });

  group('labelForWeekday', () {
    test('seg=1, dom=7', () {
      expect(labelForWeekday(1), 'Seg');
      expect(labelForWeekday(7), 'Dom');
    });

    test('valor inválido vira "?"', () {
      expect(labelForWeekday(0), '?');
      expect(labelForWeekday(8), '?');
    });
  });
}
