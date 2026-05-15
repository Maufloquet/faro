import 'package:flutter_test/flutter_test.dart';
import 'package:projeto_seg/core/stats/area_activity.dart';
import 'package:projeto_seg/models/occurrence.dart';

Occurrence _o({
  required String id,
  String? neighborhood,
  String? reason,
  double lat = -12.97,
  double lng = -38.50,
  DateTime? date,
}) {
  return Occurrence(
    id: id,
    latitude: lat,
    longitude: lng,
    date: date ?? DateTime.now(),
    neighborhood: neighborhood,
    mainReason: reason,
  );
}

void main() {
  group('rankAreas', () {
    test('lista vazia retorna lista vazia', () {
      expect(rankAreas(const []), isEmpty);
    });

    test('ignora ocorrências sem bairro', () {
      final result = rankAreas([
        _o(id: '1', neighborhood: null),
        _o(id: '2', neighborhood: ''),
      ], minCount: 1);
      expect(result, isEmpty);
    });

    test('filtra áreas abaixo do minCount', () {
      final result = rankAreas([
        _o(id: '1', neighborhood: 'Barra'),
        _o(id: '2', neighborhood: 'Barra'),
        _o(id: '3', neighborhood: 'Pituba'),
        _o(id: '4', neighborhood: 'Pituba'),
        _o(id: '5', neighborhood: 'Pituba'),
      ], minCount: 3);
      expect(result.length, 1);
      expect(result.first.name, 'Pituba');
    });

    test('ordena desc por contagem', () {
      final result = rankAreas([
        _o(id: '1', neighborhood: 'Barra'),
        _o(id: '2', neighborhood: 'Barra'),
        _o(id: '3', neighborhood: 'Pituba'),
        _o(id: '4', neighborhood: 'Pituba'),
        _o(id: '5', neighborhood: 'Pituba'),
      ], minCount: 1);
      expect(result.map((a) => a.name).toList(), ['Pituba', 'Barra']);
    });

    test('limita ao topN', () {
      final list = <Occurrence>[];
      for (final name in ['A', 'B', 'C', 'D', 'E', 'F']) {
        for (var i = 0; i < 3; i++) {
          list.add(_o(id: '$name-$i', neighborhood: name));
        }
      }
      final result = rankAreas(list, topN: 3, minCount: 1);
      expect(result.length, 3);
    });

    test('centroide é média de lat/lng', () {
      final result = rankAreas([
        _o(id: '1', neighborhood: 'X', lat: -10, lng: -40),
        _o(id: '2', neighborhood: 'X', lat: -12, lng: -42),
      ], minCount: 1);
      expect(result.first.centroidLat, closeTo(-11.0, 1e-9));
      expect(result.first.centroidLng, closeTo(-41.0, 1e-9));
    });

    test('reasonBreakdown agrupa e ordena desc', () {
      final result = rankAreas([
        _o(id: '1', neighborhood: 'X', reason: 'assalto'),
        _o(id: '2', neighborhood: 'X', reason: 'assalto'),
        _o(id: '3', neighborhood: 'X', reason: 'tiroteio'),
        _o(id: '4', neighborhood: 'X', reason: null),
      ], minCount: 1);
      final breakdown = result.first.reasonBreakdown;
      expect(breakdown.first.key, 'assalto');
      expect(breakdown.first.value, 2);
      // null vira "Não categorizado"
      expect(breakdown.any((e) => e.key == 'Não categorizado'), isTrue);
    });

    test('mostRecent é a data máxima do grupo', () {
      final base = DateTime(2026, 1, 1);
      final result = rankAreas([
        _o(id: '1', neighborhood: 'X', date: base),
        _o(id: '2', neighborhood: 'X', date: base.add(const Duration(days: 5))),
        _o(id: '3', neighborhood: 'X', date: base.add(const Duration(days: 2))),
      ], minCount: 1);
      expect(result.first.mostRecent, base.add(const Duration(days: 5)));
    });
  });
}
