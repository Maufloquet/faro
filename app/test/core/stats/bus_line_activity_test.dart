import 'package:flutter_test/flutter_test.dart';
import 'package:projeto_seg/core/stats/bus_line_activity.dart';
import 'package:projeto_seg/models/occurrence.dart';

Occurrence _o({
  required String id,
  required DateTime date,
  String? neighborhood,
  String? mainReason,
  List<String> busLines = const [],
}) =>
    Occurrence(
      id: id,
      latitude: -12.97,
      longitude: -38.50,
      date: date,
      neighborhood: neighborhood,
      mainReason: mainReason,
      busLines: busLines,
    );

void main() {
  final now = DateTime(2026, 5, 18, 12);

  group('rankBusLines', () {
    test('lista vazia → []', () {
      expect(rankBusLines(const []), isEmpty);
    });

    test('ocorrências sem busLines não entram', () {
      final r = rankBusLines([
        _o(id: 'a', date: now, neighborhood: 'Pirajá', mainReason: 'Roubo'),
        _o(id: 'b', date: now, neighborhood: 'Itapuã', mainReason: 'Tiroteio'),
      ]);
      expect(r, isEmpty);
    });

    test('linha com menos que minCount não aparece (default 2)', () {
      final r = rankBusLines([
        _o(id: 'a', date: now, busLines: const ['1234']),
      ]);
      expect(r, isEmpty);
    });

    test('linha com >= minCount aparece com contagem correta', () {
      final r = rankBusLines([
        _o(id: 'a', date: now, busLines: const ['1234'], neighborhood: 'Pirajá', mainReason: 'Roubo'),
        _o(id: 'b', date: now, busLines: const ['1234'], neighborhood: 'Pirajá', mainReason: 'Roubo'),
      ]);
      expect(r, hasLength(1));
      expect(r.first.line, '1234');
      expect(r.first.count, 2);
    });

    test('uma ocorrência conta para cada linha citada', () {
      final r = rankBusLines([
        _o(id: 'a', date: now, busLines: const ['1234', '5678']),
        _o(id: 'b', date: now, busLines: const ['1234']),
        _o(id: 'c', date: now, busLines: const ['5678']),
      ]);
      expect(r, hasLength(2));
      // 1234 tem 2 hits (a + b), 5678 tem 2 hits (a + c)
      expect(r.map((x) => x.line).toSet(), {'1234', '5678'});
    });

    test('ordenado desc por contagem', () {
      final r = rankBusLines([
        _o(id: 'a', date: now, busLines: const ['POP']),
        _o(id: 'b', date: now, busLines: const ['POP']),
        _o(id: 'c', date: now, busLines: const ['POP']),
        _o(id: 'd', date: now, busLines: const ['BAR']),
        _o(id: 'e', date: now, busLines: const ['BAR']),
      ]);
      expect(r.first.line, 'POP');
      expect(r.first.count, 3);
      expect(r.last.line, 'BAR');
    });

    test('breakdown de bairros sorted desc por contagem', () {
      final r = rankBusLines([
        _o(id: 'a', date: now, busLines: const ['1234'], neighborhood: 'Pirajá'),
        _o(id: 'b', date: now, busLines: const ['1234'], neighborhood: 'Pirajá'),
        _o(id: 'c', date: now, busLines: const ['1234'], neighborhood: 'Itapuã'),
      ]);
      final breakdown = r.first.neighborhoodBreakdown;
      expect(breakdown.first.key, 'Pirajá');
      expect(breakdown.first.value, 2);
      expect(breakdown.last.key, 'Itapuã');
    });

    test('mostRecent é a data mais nova entre as ocorrências da linha', () {
      final r = rankBusLines([
        _o(id: 'a', date: now.subtract(const Duration(days: 5)), busLines: const ['1234']),
        _o(id: 'b', date: now.subtract(const Duration(hours: 2)), busLines: const ['1234']),
        _o(id: 'c', date: now.subtract(const Duration(days: 2)), busLines: const ['1234']),
      ]);
      expect(r.first.mostRecent, now.subtract(const Duration(hours: 2)));
    });

    test('topN limita resultado', () {
      final occs = <Occurrence>[];
      for (var i = 0; i < 15; i++) {
        occs.add(_o(id: 'a$i', date: now, busLines: ['L$i']));
        occs.add(_o(id: 'b$i', date: now, busLines: ['L$i']));
      }
      final r = rankBusLines(occs, topN: 5);
      expect(r, hasLength(5));
    });

    test('mainReason null vira "Não categorizado" no breakdown', () {
      final r = rankBusLines([
        _o(id: 'a', date: now, busLines: const ['1234']),
        _o(id: 'b', date: now, busLines: const ['1234'], mainReason: 'Roubo'),
      ]);
      final reasons = r.first.reasonBreakdown.map((e) => e.key).toSet();
      expect(reasons.contains('Não categorizado'), isTrue);
      expect(reasons.contains('Roubo'), isTrue);
    });
  });
}
