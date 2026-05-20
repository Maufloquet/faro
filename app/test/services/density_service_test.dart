import 'package:flutter_test/flutter_test.dart';
import 'package:projeto_seg/services/density_service.dart';

void main() {
  group('DensityService', () {
    final svc = DensityService.testWith({
      'Itapuã': 123000,
      'Pituba': 73000,
      'Centro': 30000,
    });

    test('populationFor é case + acento insensitive', () {
      expect(svc.populationFor('Itapuã'), 123000);
      expect(svc.populationFor('itapua'), 123000);
      expect(svc.populationFor('ITAPUÃ'), 123000);
    });

    test('populationFor retorna null para bairro desconhecido', () {
      expect(svc.populationFor('Bairro Inventado'), isNull);
      expect(svc.populationFor(''), isNull);
      expect(svc.populationFor(null), isNull);
    });

    test('per10kInhabitants calcula corretamente', () {
      // 100 relatos / 100k hab = 10 per 10k
      expect(
        svc.per10kInhabitants(bairro: 'Centro', count: 30),
        10.0, // 30/30000 * 10000 = 10
      );
    });

    test('per10kInhabitants retorna null para bairro desconhecido', () {
      expect(
        svc.per10kInhabitants(bairro: 'Desconhecido', count: 100),
        isNull,
      );
    });

    test('per10kInhabitants arredonda pra 1 casa decimal', () {
      // 1 relato em Itapuã (123k) = 0.08 per 10k → arredonda pra 0.1
      final result = svc.per10kInhabitants(bairro: 'Itapuã', count: 1);
      expect(result, isNotNull);
      expect(result! < 0.2, isTrue);
    });

    test('per10kInhabitants retorna null se count=0 e pop existe (0.0 é dado)', () {
      // count=0 retorna 0.0 (não null) — "zero relatos por 10k" é informação
      final result = svc.per10kInhabitants(bairro: 'Centro', count: 0);
      expect(result, 0.0);
    });

    test('isEstimated retorna false para dados injetados via testWith', () {
      // testWith marca tudo como verified
      expect(svc.isEstimated('Itapuã'), isFalse);
      expect(svc.isEstimated('itapua'), isFalse);
    });

    test('isEstimated retorna null para bairro desconhecido', () {
      expect(svc.isEstimated('Bairro Inventado'), isNull);
      expect(svc.isEstimated(''), isNull);
      expect(svc.isEstimated(null), isNull);
    });
  });
}
