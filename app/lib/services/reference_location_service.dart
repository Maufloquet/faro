import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/log/faro_logger.dart';
import 'messaging_service.dart';

/// Endereço de referência salvo pelo usuário (hotel, casa, ponto fixo).
///
/// Caso de uso principal: turista hospedado em algum lugar quer saber se
/// houve relato no entorno do hotel **mesmo estando longe** dele agora.
/// Funciona via assinatura de tópico FCM da célula geohash5 do ponto —
/// quando ocorrência nova entra no Firestore naquela região, FCM dispara.
///
/// Atualmente: 1 endereço por device. V2 pode permitir vários (casa + trabalho).
class ReferenceLocation {
  final double lat;
  final double lng;
  /// Etiqueta livre (ex.: "Hotel Pelourinho", "Casa", "Trabalho").
  final String label;

  const ReferenceLocation({
    required this.lat,
    required this.lng,
    required this.label,
  });
}

class ReferenceLocationService {
  ReferenceLocationService._({
    MessagingService? messaging,
    SharedPreferences? prefs,
  })  : _messaging = messaging ?? MessagingService(),
        _prefsOverride = prefs;

  static final ReferenceLocationService instance =
      ReferenceLocationService._();

  /// Injeção pra testes — caller passa mock de prefs.
  ReferenceLocationService.test({
    required SharedPreferences prefs,
    MessagingService? messaging,
  })  : _messaging = messaging ?? MessagingService(),
        _prefsOverride = prefs;

  static const String _latKey = 'ref_loc_lat_v1';
  static const String _lngKey = 'ref_loc_lng_v1';
  static const String _labelKey = 'ref_loc_label_v1';
  static const String _topicKey = 'ref_loc_topic_v1';

  final MessagingService _messaging;
  final SharedPreferences? _prefsOverride;
  static const _log = FaroLogger('ref_location');

  Future<SharedPreferences> _prefs() async =>
      _prefsOverride ?? await SharedPreferences.getInstance();

  /// Lê o endereço salvo (ou null se não há).
  Future<ReferenceLocation?> current() async {
    final prefs = await _prefs();
    final lat = prefs.getDouble(_latKey);
    final lng = prefs.getDouble(_lngKey);
    final label = prefs.getString(_labelKey);
    if (lat == null || lng == null) return null;
    return ReferenceLocation(lat: lat, lng: lng, label: label ?? 'Local salvo');
  }

  /// Salva um endereço novo. Assina o tópico FCM correspondente ao
  /// geohash5 da posição. Se já havia outro endereço, desassina o
  /// tópico antigo pra não receber alerta de área que não interessa mais.
  Future<void> save(ReferenceLocation loc) async {
    final prefs = await _prefs();

    final newTopic = 'reference_${geohash5Of(loc.lat, loc.lng)}';
    final oldTopic = prefs.getString(_topicKey);

    if (oldTopic != null && oldTopic.isNotEmpty && oldTopic != newTopic) {
      try {
        await _messaging.unsubscribeFromTopic(oldTopic);
      } catch (e, s) {
        _log.error('falha removendo tópico antigo', e, s);
      }
    }

    try {
      await _messaging.subscribeToTopic(newTopic);
    } catch (e, s) {
      _log.error('falha inscrevendo no tópico de referência', e, s);
    }

    await prefs.setDouble(_latKey, loc.lat);
    await prefs.setDouble(_lngKey, loc.lng);
    await prefs.setString(_labelKey, loc.label);
    await prefs.setString(_topicKey, newTopic);
    _log.info('referência salva: ${loc.label} ($newTopic)');

    // Sync pra cloud só quando o usuário está logado (não-anônimo).
    // Falha silenciosa — local de referência continua funcional só no device.
    unawaited(_syncToCloud(loc));
  }

  /// Remove o endereço salvo e desinscreve do tópico correspondente.
  Future<void> clear() async {
    final prefs = await _prefs();
    final topic = prefs.getString(_topicKey);
    if (topic != null && topic.isNotEmpty) {
      try {
        await _messaging.unsubscribeFromTopic(topic);
      } catch (e, s) {
        _log.error('falha removendo tópico ao limpar', e, s);
      }
    }
    await prefs.remove(_latKey);
    await prefs.remove(_lngKey);
    await prefs.remove(_labelKey);
    await prefs.remove(_topicKey);
    _log.info('referência limpa');
    unawaited(_clearCloud());
  }

  // ─── Sync com Firestore (só ativo quando usuário não-anônimo) ─────────
  //
  // Persistência fica em `/users/{uid}.referenceLocation`. Anonymous user
  // continua usando só SharedPreferences (princípio "sem cadastro").

  /// Retorna o usuário autenticado ou `null` quando Firebase não está
  /// inicializado (modo dev/test). `FirebaseAuth.instance` lança nesse
  /// caso, então isolamos pra cloud sync degradar gracioso em vez de
  /// estourar exceção pro caller que só queria salvar localmente.
  User? _safeCurrentUser() {
    try {
      return FirebaseAuth.instance.currentUser;
    } catch (_) {
      return null;
    }
  }

  Future<void> _syncToCloud(ReferenceLocation loc) async {
    final user = _safeCurrentUser();
    if (user == null || user.isAnonymous) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'referenceLocation': {
          'lat': loc.lat,
          'lng': loc.lng,
          'label': loc.label,
        },
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      _log.info('cloud sync ok: ${loc.label}');
    } catch (e, s) {
      _log.error('cloud sync falhou', e, s);
    }
  }

  Future<void> _clearCloud() async {
    final user = _safeCurrentUser();
    if (user == null || user.isAnonymous) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'referenceLocation': FieldValue.delete(),
      }, SetOptions(merge: true));
    } catch (e, s) {
      _log.error('cloud clear falhou', e, s);
    }
  }

  /// Pull on login — após o usuário entrar com Google, busca a
  /// referência salva em outro device e popula o prefs local.
  /// No-op pra anonymous user. Chamado pelo listener de auth no boot.
  Future<void> pullFromCloud() async {
    final user = _safeCurrentUser();
    if (user == null || user.isAnonymous) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = doc.data();
      if (data == null) return;
      final raw = data['referenceLocation'];
      if (raw is! Map) return;
      final lat = (raw['lat'] as num?)?.toDouble();
      final lng = (raw['lng'] as num?)?.toDouble();
      final label = raw['label'] as String?;
      if (lat == null || lng == null) return;
      final remote = ReferenceLocation(
        lat: lat,
        lng: lng,
        label: label ?? 'Local salvo',
      );
      final local = await current();
      if (local == null ||
          local.lat != remote.lat ||
          local.lng != remote.lng) {
        await save(remote);
        _log.info('pulled from cloud: ${remote.label}');
      }
    } catch (e, s) {
      _log.error('pull from cloud falhou', e, s);
    }
  }

  /// Re-assina o tópico no boot — útil porque o FCM pode perder
  /// subscriptions quando o dispositivo fica muito tempo offline.
  Future<void> resumeOnBoot() async {
    final loc = await current();
    if (loc == null) return;
    final topic = 'reference_${geohash5Of(loc.lat, loc.lng)}';
    try {
      await _messaging.subscribeToTopic(topic);
      _log.debug('boot resume: re-assinado $topic');
    } catch (e, s) {
      _log.error('boot resume falhou', e, s);
    }
  }
}

final referenceLocationProvider = Provider<ReferenceLocationService>(
  (_) => ReferenceLocationService.instance,
);

final currentReferenceProvider = FutureProvider<ReferenceLocation?>(
  (ref) => ref.watch(referenceLocationProvider).current(),
);
