import 'package:flutter_test/flutter_test.dart';
import 'package:projeto_seg/core/theme/app_theme.dart';
import 'package:projeto_seg/models/occurrence.dart';
import 'package:projeto_seg/services/cluster_engine.dart';

Occurrence _o(String id, double lat, double lng, {DateTime? date}) => Occurrence(
      id: id,
      latitude: lat,
      longitude: lng,
      date: date ?? DateTime.now(),
    );

void main() {
  const refLat = -12.9714; // centroide de Salvador, usado pelo MapScreen

  group('clusterOccurrences', () {
    test('lista vazia retorna lista vazia em qualquer zoom', () {
      expect(
        clusterOccurrences(occurrences: const [], zoom: 12, referenceLat: refLat),
        isEmpty,
      );
      expect(
        clusterOccurrences(occurrences: const [], zoom: 16, referenceLat: refLat),
        isEmpty,
      );
    });

    test('zoom abaixo do heatmap threshold devolve nós individuais', () {
      final occ = [_o('a', -12.97, -38.50), _o('b', -12.98, -38.51)];
      final nodes = clusterOccurrences(
        occurrences: occ,
        zoom: 12,
        referenceLat: refLat,
      );
      expect(nodes, hasLength(2));
      expect(nodes.every((n) => !n.isCluster), isTrue);
    });

    test('zoom acima do ceiling devolve nós individuais (street-level)', () {
      final occ = [
        _o('a', -12.9714, -38.5014),
        // 5m ao lado: bem dentro de qualquer célula clusterizável
        _o('b', -12.97145, -38.50145),
      ];
      final nodes = clusterOccurrences(
        occurrences: occ,
        zoom: 17.5,
        referenceLat: refLat,
      );
      expect(nodes, hasLength(2));
      expect(nodes.every((n) => !n.isCluster), isTrue);
    });

    test('na faixa de cluster, pontos próximos viram um único nó com centroide', () {
      final occ = [
        _o('a', -12.9714, -38.5014),
        _o('b', -12.97145, -38.50145),
      ];
      final nodes = clusterOccurrences(
        occurrences: occ,
        zoom: 15,
        referenceLat: refLat,
      );
      expect(nodes, hasLength(1));
      final node = nodes.first;
      expect(node.isCluster, isTrue);
      expect(node.count, 2);
      // Centroide é a média simples.
      expect(node.lat, closeTo((-12.9714 + -12.97145) / 2, 1e-9));
      expect(node.lng, closeTo((-38.5014 + -38.50145) / 2, 1e-9));
    });

    test('pontos distantes na faixa de cluster permanecem separados', () {
      final occ = [
        _o('a', -12.9714, -38.5014), // Pelourinho
        _o('b', -12.8895, -38.3260), // Lauro (~21km)
      ];
      final nodes = clusterOccurrences(
        occurrences: occ,
        zoom: 15,
        referenceLat: refLat,
      );
      expect(nodes, hasLength(2));
      expect(nodes.every((n) => !n.isCluster), isTrue);
    });

    test('risk do cluster herda do relato mais recente', () {
      final now = DateTime.now();
      final occ = [
        // 3 dias atrás → lightActivity
        _o('old', -12.9714, -38.5014, date: now.subtract(const Duration(days: 3))),
        // 2 horas atrás → highCorroborated
        _o('new', -12.97145, -38.50145, date: now.subtract(const Duration(hours: 2))),
      ];
      final nodes = clusterOccurrences(
        occurrences: occ,
        zoom: 15,
        referenceLat: refLat,
      );
      expect(nodes, hasLength(1));
      expect(nodes.first.risk, RiskLevel.highCorroborated);
    });
  });
}
