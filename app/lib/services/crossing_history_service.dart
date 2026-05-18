import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/log/faro_logger.dart';
import '../models/crossing_event.dart';

/// Persiste cruzamentos do usuário com zonas de ocorrência.
///
/// Armazenamento: SharedPreferences (suficiente — ~5 eventos/dia × 7 dias
/// = 35 entradas, é nada). Banco real só faria sentido se virar histórico
/// de meses.
///
/// Política:
/// - Dedup por (bairro, mesmo dia local): evita registrar 10x o mesmo
///   bairro durante o dia
/// - Limite: até 5 cruzamentos por dia entram no histórico (e disparam
///   notificação). O 6º em diante é silenciado pra não virar ruído
/// - Lifecycle: eventos com > 7 dias são removidos automaticamente toda
///   vez que carregamos o histórico
class CrossingHistoryService {
  CrossingHistoryService._({SharedPreferences? prefs}) : _prefsOverride = prefs;

  static final CrossingHistoryService instance = CrossingHistoryService._();

  /// Usado em testes — caller pode injetar mock de SharedPreferences.
  CrossingHistoryService.test(SharedPreferences prefs)
      : _prefsOverride = prefs;

  static const String _storageKey = 'crossing_history_v1';
  static const int _maxPerDay = 5;
  static const Duration _retention = Duration(days: 7);

  final SharedPreferences? _prefsOverride;
  static const _log = FaroLogger('crossing_history');

  Future<SharedPreferences> _prefs() async =>
      _prefsOverride ?? await SharedPreferences.getInstance();

  /// Registra um cruzamento. Retorna `true` se o evento foi salvo, `false`
  /// se foi descartado (dedup ou limite diário). Aplica limpeza de
  /// eventos antigos antes.
  ///
  /// O caller usa o retorno pra decidir se também dispara notif local —
  /// histórico e notif compartilham a mesma decisão de "vale registrar".
  Future<bool> tryRecord(CrossingEvent event) async {
    final prefs = await _prefs();
    final existing = _loadFromPrefs(prefs);
    final cleaned = _dropExpired(existing);

    if (_isDuplicateInDay(cleaned, event)) {
      _log.debug('dedup: bairro ${event.neighborhood} já registrado hoje');
      await _persist(prefs, cleaned);
      return false;
    }

    final todayCount = _countSameDay(cleaned, event.at);
    if (todayCount >= _maxPerDay) {
      _log.debug('limite diário atingido ($_maxPerDay), descartando');
      await _persist(prefs, cleaned);
      return false;
    }

    final updated = [...cleaned, event];
    await _persist(prefs, updated);
    _log.info('cruzamento registrado: ${event.neighborhood} · ${event.reportCount} relatos');
    return true;
  }

  /// Retorna todos os cruzamentos válidos (< 7 dias), mais novos primeiro.
  /// Limpa eventos expirados como side-effect.
  Future<List<CrossingEvent>> recent() async {
    final prefs = await _prefs();
    final loaded = _loadFromPrefs(prefs);
    final cleaned = _dropExpired(loaded);
    if (cleaned.length != loaded.length) {
      await _persist(prefs, cleaned);
    }
    cleaned.sort((a, b) => b.at.compareTo(a.at));
    return cleaned;
  }

  /// Apaga todo o histórico. Usado se o usuário desativar tracking.
  Future<void> clear() async {
    final prefs = await _prefs();
    await prefs.remove(_storageKey);
  }

  // ─── Internals ────────────────────────────────────────────────────────

  List<CrossingEvent> _loadFromPrefs(SharedPreferences prefs) {
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .whereType<Map<String, dynamic>>()
          .map(CrossingEvent.fromMap)
          .toList();
    } catch (e, st) {
      _log.error('storage corrompido, descartando', e, st);
      return [];
    }
  }

  Future<void> _persist(SharedPreferences prefs, List<CrossingEvent> events) async {
    final encoded = jsonEncode(events.map((e) => e.toMap()).toList());
    await prefs.setString(_storageKey, encoded);
  }

  List<CrossingEvent> _dropExpired(List<CrossingEvent> events) {
    final cutoff = DateTime.now().subtract(_retention);
    return events.where((e) => e.at.isAfter(cutoff)).toList();
  }

  bool _isDuplicateInDay(List<CrossingEvent> events, CrossingEvent candidate) {
    final dayKey = _dayKey(candidate.at);
    final neighKey = (candidate.neighborhood ?? '').toLowerCase().trim();
    if (neighKey.isEmpty) return false;
    return events.any((e) =>
        _dayKey(e.at) == dayKey &&
        (e.neighborhood ?? '').toLowerCase().trim() == neighKey);
  }

  int _countSameDay(List<CrossingEvent> events, DateTime date) {
    final key = _dayKey(date);
    return events.where((e) => _dayKey(e.at) == key).length;
  }

  String _dayKey(DateTime dt) {
    final local = dt.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }
}

/// Provider Riverpod — singleton compartilhado.
final crossingHistoryProvider = Provider<CrossingHistoryService>(
  (_) => CrossingHistoryService.instance,
);

/// Stream do histórico recente. Recarrega manualmente via `ref.refresh`
/// quando uma nova entrada é adicionada (background service emite hint).
final crossingHistoryStreamProvider = FutureProvider<List<CrossingEvent>>(
  (ref) => ref.watch(crossingHistoryProvider).recent(),
);
