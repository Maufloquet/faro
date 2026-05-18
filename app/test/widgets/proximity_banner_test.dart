import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:projeto_seg/models/occurrence.dart';
import 'package:projeto_seg/widgets/proximity_banner.dart';

Occurrence _o({
  String id = 'a',
  String? mainReason,
  required DateTime date,
}) =>
    Occurrence(
      id: id,
      latitude: -12.97,
      longitude: -38.50,
      date: date,
      mainReason: mainReason,
    );

Future<void> _pump(
  WidgetTester tester,
  Widget banner,
) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Stack(children: [banner]),
      ),
    ),
  );
}

void main() {
  // Relógio fixo pra estabilizar a string "há X min" no CI.
  final fixedNow = DateTime(2026, 5, 17, 12);
  DateTime nowStub() => fixedNow;

  group('ProximityBanner — copy editorial', () {
    testWidgets('1 alerta exibe headline singular', (tester) async {
      final alert = _o(
        date: fixedNow.subtract(const Duration(minutes: 15)),
        mainReason: 'Tiroteio',
      );
      await _pump(
        tester,
        ProximityBanner(
          alerts: [alert],
          onTap: () {},
          onDismiss: () {},
          now: nowStub,
        ),
      );
      expect(find.text('Novo relato perto de você'), findsOneWidget);
      expect(find.text('Tiroteio · há 15 min'), findsOneWidget);
    });

    testWidgets('N alertas exibe headline pluralizado', (tester) async {
      final alerts = [
        _o(date: fixedNow.subtract(const Duration(hours: 1)), mainReason: 'Tiroteio'),
        _o(id: 'b', date: fixedNow.subtract(const Duration(hours: 3)), mainReason: 'Roubo'),
        _o(id: 'c', date: fixedNow.subtract(const Duration(hours: 5)), mainReason: 'Agressão'),
      ];
      await _pump(
        tester,
        ProximityBanner(
          alerts: alerts,
          onTap: () {},
          onDismiss: () {},
          now: nowStub,
        ),
      );
      expect(find.text('3 relatos próximos nas últimas 6h'), findsOneWidget);
      // Mais recente = primeiro da lista (callsite ordena desc por data).
      expect(find.text('Mais recente: Tiroteio · há 1h'), findsOneWidget);
    });

    testWidgets('mainReason ausente cai pra fallback genérico', (tester) async {
      final alert = _o(
        date: fixedNow.subtract(const Duration(minutes: 30)),
      );
      await _pump(
        tester,
        ProximityBanner(
          alerts: [alert],
          onTap: () {},
          onDismiss: () {},
          now: nowStub,
        ),
      );
      expect(find.text('Relato · há 30 min'), findsOneWidget);
    });

    testWidgets('formato muda de "min" pra "h" depois de 60 min', (tester) async {
      final alert = _o(
        date: fixedNow.subtract(const Duration(hours: 2)),
        mainReason: 'Roubo',
      );
      await _pump(
        tester,
        ProximityBanner(
          alerts: [alert],
          onTap: () {},
          onDismiss: () {},
          now: nowStub,
        ),
      );
      expect(find.text('Roubo · há 2h'), findsOneWidget);
    });
  });

  group('ProximityBanner — tom editorial (princípio Faro)', () {
    testWidgets('nunca usa palavras alarmistas (PERIGO/CUIDADO/EVITE/URGENTE)',
        (tester) async {
      final alerts = [
        _o(date: fixedNow.subtract(const Duration(minutes: 5)), mainReason: 'Tiroteio'),
        _o(id: 'b', date: fixedNow.subtract(const Duration(hours: 2)), mainReason: 'Homicídio'),
      ];
      await _pump(
        tester,
        ProximityBanner(
          alerts: alerts,
          onTap: () {},
          onDismiss: () {},
          now: nowStub,
        ),
      );

      const proibidas = ['PERIGO', 'CUIDADO', 'EVITE', 'URGENTE', 'ALERTA'];
      final textWidgets = tester.widgetList<Text>(find.byType(Text));
      for (final w in textWidgets) {
        final raw = w.data;
        if (raw == null) continue;
        final up = raw.toUpperCase();
        for (final p in proibidas) {
          expect(up.contains(p), isFalse,
              reason: 'Banner exibiu "$raw", que contém "$p" (proibido pelo tom editorial)');
        }
      }
    });
  });

  group('ProximityBanner — interações', () {
    testWidgets('tap no corpo dispara onTap', (tester) async {
      var tapped = false;
      await _pump(
        tester,
        ProximityBanner(
          alerts: [_o(date: fixedNow.subtract(const Duration(minutes: 5)), mainReason: 'Tiroteio')],
          onTap: () => tapped = true,
          onDismiss: () {},
          now: nowStub,
        ),
      );
      await tester.tap(find.text('Novo relato perto de você'));
      expect(tapped, isTrue);
    });

    testWidgets('tap no X dispara onDismiss (e não onTap)', (tester) async {
      var tapped = false;
      var dismissed = false;
      await _pump(
        tester,
        ProximityBanner(
          alerts: [_o(date: fixedNow.subtract(const Duration(minutes: 5)), mainReason: 'Tiroteio')],
          onTap: () => tapped = true,
          onDismiss: () => dismissed = true,
          now: nowStub,
        ),
      );
      await tester.tap(find.byTooltip('Dispensar'));
      expect(dismissed, isTrue);
      expect(tapped, isFalse);
    });
  });
}
