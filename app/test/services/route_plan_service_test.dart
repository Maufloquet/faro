import 'package:flutter_test/flutter_test.dart';
import 'package:projeto_seg/models/occurrence.dart';
import 'package:projeto_seg/models/route_plan.dart';
import 'package:projeto_seg/services/route_plan_service.dart';

Occurrence fakeOccurrence({
  required double lat,
  required double lng,
  required Duration ageBack,
  String? id,
}) {
  return Occurrence(
    id: id ?? 'o-$lat-$lng',
    latitude: lat,
    longitude: lng,
    date: DateTime.now().subtract(ageBack),
    state: 'Bahia',
    city: 'Salvador',
    source: OccurrenceSource.media,
    weight: 0.3,
  );
}

void main() {
  final service = RoutePlanService();
  // Rota da Pituba (~ -12.997, -38.461) ao Iguatemi (~ -12.978, -38.460).
  const plan = RoutePlan(
    originLat: -12.997,
    originLng: -38.461,
    destinationLat: -12.978,
    destinationLng: -38.460,
  );

  test('inclui relato no corredor dentro da janela', () {
    // Ponto na linha, recente.
    final occ = fakeOccurrence(
      lat: -12.987,
      lng: -38.460,
      ageBack: const Duration(hours: 2),
    );
    final eval = service.evaluate(plan, [occ]);
    expect(eval.count, 1);
    expect(eval.headline(), contains('1 relato'));
  });

  test('exclui relato fora do corredor', () {
    final occ = fakeOccurrence(
      lat: -12.987,
      lng: -38.500, // ~4km a oeste
      ageBack: const Duration(hours: 2),
    );
    final eval = service.evaluate(plan, [occ]);
    expect(eval.count, 0);
    expect(eval.headline(), contains('Trajeto sem relatos'));
  });

  test('exclui relato fora da janela temporal', () {
    final occ = fakeOccurrence(
      lat: -12.987,
      lng: -38.460,
      ageBack: const Duration(hours: 24), // muito antigo
    );
    final eval = service.evaluate(plan, [occ]);
    expect(eval.count, 0);
  });

  test('ordena resultados do mais recente pro mais antigo', () {
    final a = fakeOccurrence(
      id: 'a',
      lat: -12.987,
      lng: -38.460,
      ageBack: const Duration(hours: 4),
    );
    final b = fakeOccurrence(
      id: 'b',
      lat: -12.985,
      lng: -38.460,
      ageBack: const Duration(hours: 1),
    );
    final eval = service.evaluate(plan, [a, b]);
    expect(eval.count, 2);
    expect(eval.inCorridor[0].id, 'b');
    expect(eval.inCorridor[1].id, 'a');
  });

  test('headline pluraliza corretamente', () {
    final occs = List.generate(
      3,
      (i) => fakeOccurrence(
        id: 'o$i',
        lat: -12.985 + i * 0.001,
        lng: -38.460,
        ageBack: Duration(hours: i + 1),
      ),
    );
    final eval = service.evaluate(plan, occs);
    expect(eval.headline(), contains('3 relatos'));
  });

  test('headline nunca contém palavras alarmistas', () {
    final occ = fakeOccurrence(
      lat: -12.987,
      lng: -38.460,
      ageBack: const Duration(minutes: 30),
    );
    final eval = service.evaluate(plan, [occ]);
    final text = eval.headline();
    for (final banned in ['PERIGO', 'CUIDADO', 'EVITE', 'URGENTE']) {
      expect(text.toUpperCase().contains(banned), isFalse,
          reason: 'headline contém "$banned"');
    }
  });
}
