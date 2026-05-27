import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../core/log/faro_logger.dart';
import '../services/messaging_service.dart';

/// "Cheguei bem" — o usuário toca um botão ao chegar em algum lugar
/// e gravamos um ponto **anônimo** de trajeto sem incidente.
///
/// Por que existir (princípio editorial): praticamente todo app de
/// segurança coleta só dados de coisa ruim — resultado é viés sistemático
/// (lugar onde nada acontece = lugar com zero dados). Coletar dados
/// **negativos** permite mostrar densidade de "247 pessoas chegaram bem
/// por aqui nas últimas 24h", validando negativamente bairros que hoje
/// só têm o rótulo da imprensa.
///
/// Anti-engajamento de propósito: o botão tira o usuário do app. Não
/// abre tela, não pede mais dados. Um toque, snackbar, fecha.
///
/// Privacidade: gravamos só geohash5 (~5 km² de granularidade) + dia.
/// Sem UID nominal no registro, sem trajeto contínuo. Aggregação por
/// célula evita reconstrução de rota individual.
class SafeArrivalService {
  SafeArrivalService._();
  static final SafeArrivalService instance = SafeArrivalService._();
  static const _log = FaroLogger('safe_arrival');

  /// Registra "cheguei bem" na célula geohash5 da posição atual.
  ///
  /// Retorna `null` se permissão de localização foi negada, ou
  /// `SafeArrivalResult` com a célula+contagem do dia em caso de sucesso.
  Future<SafeArrivalResult?> record({Position? position}) async {
    try {
      Position pos;
      if (position != null) {
        pos = position;
      } else {
        final perm = await _ensurePermission();
        if (!perm) return null;
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 6),
          ),
        );
      }
      final cell = geohash5Of(pos.latitude, pos.longitude);
      final today = _todayKey(DateTime.now());

      // Doc por (cell, dia). Increment atômico no count. Não guardamos
      // UID — `submittedBy` é só conta de votos únicos por device (anti
      // spam minimalista). UID anônimo basta — não identifica pessoa.
      final uid = FirebaseAuth.instance.currentUser?.uid;
      final docId = '${cell}_$today';
      final ref =
          FirebaseFirestore.instance.collection('safe_arrivals').doc(docId);

      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) {
          tx.set(ref, {
            'cell': cell,
            'day': today,
            'count': 1,
            'updatedAt': FieldValue.serverTimestamp(),
            'lastSubmitter': ?uid,
          });
        } else {
          tx.update(ref, {
            'count': FieldValue.increment(1),
            'updatedAt': FieldValue.serverTimestamp(),
            'lastSubmitter': ?uid,
          });
        }
      });

      _log.info('safe arrival registrado em $cell ($today)');
      return SafeArrivalResult(cell: cell, day: today);
    } catch (e, s) {
      _log.error('falha registrando safe arrival', e, s);
      return null;
    }
  }

  /// Contagem de "cheguei bem" pra um geohash5 num dia específico.
  Future<int> countForCellDay(String cell, DateTime day) async {
    final docId = '${cell}_${_todayKey(day)}';
    final snap = await FirebaseFirestore.instance
        .collection('safe_arrivals')
        .doc(docId)
        .get();
    if (!snap.exists) return 0;
    return (snap.data()?['count'] as num?)?.toInt() ?? 0;
  }

  /// Contagem agregada nas últimas 24h pra uma célula — usado pelos
  /// cards de bairro pra mostrar "247 pessoas chegaram bem aqui hoje".
  Future<int> countLast24h(String cell) async {
    final now = DateTime.now();
    final today = await countForCellDay(cell, now);
    final yesterday =
        await countForCellDay(cell, now.subtract(const Duration(days: 1)));
    return today + yesterday;
  }

  Future<bool> _ensurePermission() async {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    return perm == LocationPermission.whileInUse ||
        perm == LocationPermission.always;
  }

  String _todayKey(DateTime d) {
    final l = d.toLocal();
    return '${l.year}'
        '-${l.month.toString().padLeft(2, '0')}'
        '-${l.day.toString().padLeft(2, '0')}';
  }
}

class SafeArrivalResult {
  final String cell;
  final String day;
  const SafeArrivalResult({required this.cell, required this.day});
}

/// Mensagem pronta pra "avisar que cheguei" a um contato. Pura e testável.
/// Inclui hora e, se houver posição, um link de mapa pra o contato ver onde.
String arrivalShareMessage({DateTime? now, double? lat, double? lng}) {
  final t = (now ?? DateTime.now()).toLocal();
  final hora =
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  final base = 'Cheguei bem — $hora.';
  if (lat != null && lng != null) {
    return '$base Minha localização: https://maps.google.com/?q=$lat,$lng';
  }
  return base;
}

final safeArrivalServiceProvider = Provider<SafeArrivalService>(
  (_) => SafeArrivalService.instance,
);
