import 'package:projeto_seg/models/user_report.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ReportType.parse', () {
    test('mapeia ids canônicos (casam com occurrence_type do newsIngest)', () {
      expect(ReportType.parse('tiroteio'), ReportType.tiroteio);
      expect(ReportType.parse('roubo'), ReportType.roubo);
      expect(ReportType.parse('homicidio'), ReportType.homicidio);
      expect(ReportType.parse('agressao'), ReportType.agressao);
      expect(ReportType.parse('acao_policial'), ReportType.acaoPolicial);
      expect(ReportType.parse('outros'), ReportType.outros);
    });

    test('desconhecido e null caem em outros', () {
      expect(ReportType.parse('qualquer'), ReportType.outros);
      expect(ReportType.parse(null), ReportType.outros);
    });

    test('todo tipo tem label não-vazio', () {
      for (final t in ReportType.values) {
        expect(t.label.trim(), isNotEmpty);
      }
    });
  });

  group('ReportStatus.parse', () {
    test('mapeia os estados conhecidos', () {
      expect(ReportStatus.parse('pending'), ReportStatus.pending);
      expect(ReportStatus.parse('confirmed'), ReportStatus.confirmed);
      expect(ReportStatus.parse('rejected'), ReportStatus.rejected);
      expect(ReportStatus.parse('expired'), ReportStatus.expired);
    });

    test('desconhecido e null caem em unknown', () {
      expect(ReportStatus.parse('xpto'), ReportStatus.unknown);
      expect(ReportStatus.parse(null), ReportStatus.unknown);
    });
  });
}
