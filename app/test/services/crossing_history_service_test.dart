import 'package:flutter_test/flutter_test.dart';
import 'package:projeto_seg/models/crossing_event.dart';
import 'package:projeto_seg/services/crossing_history_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

CrossingEvent _event({
  required String neighborhood,
  required DateTime at,
  int count = 2,
}) =>
    CrossingEvent(
      id: at.millisecondsSinceEpoch,
      at: at,
      neighborhood: neighborhood,
      city: 'Salvador',
      reportCount: count,
      topReasons: const ['Roubo', 'Tiroteio'],
      occurrenceIds: const ['x1', 'x2'],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CrossingHistoryService svc;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    // setMockInitialValues não invalida o singleton já cacheado em testes
    // anteriores — clear() garante que a chave do crossing history começa
    // vazia em cada caso.
    await prefs.clear();
    svc = CrossingHistoryService.test(prefs);
  });

  group('tryRecord', () {
    test('registra evento novo', () async {
      final ok = await svc.tryRecord(
        _event(neighborhood: 'Pirajá', at: DateTime.now()),
      );
      expect(ok, isTrue);
      final all = await svc.recent();
      expect(all, hasLength(1));
    });

    test('dedup: mesmo bairro no mesmo dia retorna false', () async {
      final now = DateTime.now();
      final first = await svc.tryRecord(_event(neighborhood: 'Pirajá', at: now));
      final second = await svc.tryRecord(
        _event(neighborhood: 'Pirajá', at: now.add(const Duration(hours: 2))),
      );
      expect(first, isTrue);
      expect(second, isFalse);
      final all = await svc.recent();
      expect(all, hasLength(1));
    });

    test('mesmo bairro em dias diferentes é registrado normalmente', () async {
      final today = DateTime.now();
      final yesterday = today.subtract(const Duration(days: 1));
      await svc.tryRecord(_event(neighborhood: 'Pirajá', at: yesterday));
      await svc.tryRecord(_event(neighborhood: 'Pirajá', at: today));
      final all = await svc.recent();
      expect(all, hasLength(2));
    });

    test('limite de 5 cruzamentos por dia', () async {
      final now = DateTime.now();
      for (var i = 0; i < 6; i++) {
        await svc.tryRecord(_event(
          neighborhood: 'Bairro$i',
          at: now.add(Duration(minutes: i)),
        ));
      }
      final all = await svc.recent();
      expect(all, hasLength(5), reason: 'Sexto evento deve ser descartado');
    });

    test('dedup é case + acento insensitive na pratica', () async {
      // O service compara via toLowerCase().trim(). Não strip de acento.
      // Documentando comportamento atual no teste.
      final now = DateTime.now();
      await svc.tryRecord(_event(neighborhood: 'Pirajá', at: now));
      final second = await svc.tryRecord(_event(
        neighborhood: 'PIRAJÁ',
        at: now.add(const Duration(hours: 1)),
      ));
      expect(second, isFalse);
    });
  });

  group('recent', () {
    test('lista vazia quando não há registros', () async {
      final all = await svc.recent();
      expect(all, isEmpty);
    });

    test('eventos > 7 dias são removidos automaticamente', () async {
      final old = DateTime.now().subtract(const Duration(days: 8));
      final fresh = DateTime.now();
      await svc.tryRecord(_event(neighborhood: 'OldHood', at: old));
      await svc.tryRecord(_event(neighborhood: 'NewHood', at: fresh));
      final all = await svc.recent();
      expect(all, hasLength(1));
      expect(all.first.neighborhood, 'NewHood');
    });

    test('ordena do mais recente pro mais antigo', () async {
      final now = DateTime.now();
      await svc.tryRecord(_event(
        neighborhood: 'A',
        at: now.subtract(const Duration(days: 3)),
      ));
      await svc.tryRecord(_event(
        neighborhood: 'B',
        at: now.subtract(const Duration(days: 1)),
      ));
      await svc.tryRecord(_event(neighborhood: 'C', at: now));

      final all = await svc.recent();
      expect(all.map((e) => e.neighborhood).toList(), ['C', 'B', 'A']);
    });
  });

  group('clear', () {
    test('apaga todo o histórico', () async {
      await svc.tryRecord(_event(neighborhood: 'X', at: DateTime.now()));
      await svc.clear();
      expect(await svc.recent(), isEmpty);
    });
  });

  group('serialização', () {
    test('round-trip pelo storage preserva campos', () async {
      // Data ancorada em "agora menos 2 dias" pra ficar sempre dentro da
      // janela de retenção (7 dias) — uma data fixa apodrece e some do
      // recent(). Truncada no minuto pra não ter microssegundos que o
      // round-trip por millisecondsSinceEpoch perderia.
      final base = DateTime.now().subtract(const Duration(days: 2));
      final original = CrossingEvent(
        id: 12345,
        at: DateTime(base.year, base.month, base.day, 14, 30),
        neighborhood: 'Pirajá',
        city: 'Salvador',
        reportCount: 5,
        topReasons: const ['Roubo', 'Tiroteio', 'Agressão'],
        occurrenceIds: const ['a', 'b', 'c'],
      );
      await svc.tryRecord(original);

      // Cria nova instância usando o mesmo prefs — simula reabertura do app.
      final prefs = await SharedPreferences.getInstance();
      final svc2 = CrossingHistoryService.test(prefs);
      final loaded = await svc2.recent();

      expect(loaded, hasLength(1));
      final r = loaded.first;
      expect(r.id, original.id);
      expect(r.neighborhood, original.neighborhood);
      expect(r.city, original.city);
      expect(r.reportCount, original.reportCount);
      expect(r.topReasons, original.topReasons);
      expect(r.occurrenceIds, original.occurrenceIds);
      expect(r.at.toUtc(), original.at.toUtc());
    });
  });
}
