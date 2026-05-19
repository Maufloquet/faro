import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/log/faro_logger.dart';

/// Um bairro favorito — coisa que o usuário marca pra "ficar de olho"
/// (ex.: turista marca Pelourinho, Barra e Itapuã; entregador marca os
/// 5 bairros onde mais opera). Aparece na tela "Favoritos" do drawer.
class FavoriteNeighborhood {
  final String id; // slug normalizado (lowercase, sem acento) — chave
  final String name; // como veio do user/source (capitalização original)
  final String? city;
  final double centroidLat;
  final double centroidLng;
  final DateTime addedAt;

  const FavoriteNeighborhood({
    required this.id,
    required this.name,
    required this.city,
    required this.centroidLat,
    required this.centroidLng,
    required this.addedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'city': city,
        'lat': centroidLat,
        'lng': centroidLng,
        'addedAt': addedAt.toIso8601String(),
      };

  factory FavoriteNeighborhood.fromJson(Map<String, dynamic> j) =>
      FavoriteNeighborhood(
        id: j['id'] as String,
        name: j['name'] as String,
        city: j['city'] as String?,
        centroidLat: (j['lat'] as num).toDouble(),
        centroidLng: (j['lng'] as num).toDouble(),
        addedAt: DateTime.tryParse(j['addedAt'] as String? ?? '') ??
            DateTime.now(),
      );
}

/// Normaliza um nome de bairro pra chave estável (`Mata Escura` →
/// `mata-escura`). Usado como id pra dedupar entre PT/case variations.
String normalizeNeighborhoodId(String name) {
  return name
      .toLowerCase()
      .replaceAll(RegExp(r'[áàâãä]'), 'a')
      .replaceAll(RegExp(r'[éèêë]'), 'e')
      .replaceAll(RegExp(r'[íìîï]'), 'i')
      .replaceAll(RegExp(r'[óòôõö]'), 'o')
      .replaceAll(RegExp(r'[úùûü]'), 'u')
      .replaceAll(RegExp(r'[ç]'), 'c')
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
}

/// Serviço de favoritos. Persiste localmente em SharedPreferences
/// (JSON serializado) e, quando o usuário está logado, sincroniza com
/// `/users/{uid}/favorites/{id}` no Firestore.
class FavoritesService {
  FavoritesService._({SharedPreferences? prefs}) : _prefsOverride = prefs;
  static final FavoritesService instance = FavoritesService._();

  /// Injeção pra testes.
  FavoritesService.test({required SharedPreferences prefs})
      : _prefsOverride = prefs;

  static const _prefsKey = 'favorites_v1';
  static const _log = FaroLogger('favorites');

  final SharedPreferences? _prefsOverride;
  Future<SharedPreferences> _prefs() async =>
      _prefsOverride ?? await SharedPreferences.getInstance();

  Future<List<FavoriteNeighborhood>> all() async {
    final prefs = await _prefs();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => FavoriteNeighborhood.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.addedAt.compareTo(a.addedAt));
    } catch (e) {
      _log.error('parse falhou, zerando favorites', e);
      await prefs.remove(_prefsKey);
      return [];
    }
  }

  Future<bool> isFavorite(String neighborhoodName) async {
    final id = normalizeNeighborhoodId(neighborhoodName);
    final list = await all();
    return list.any((f) => f.id == id);
  }

  Future<void> add(FavoriteNeighborhood fav) async {
    final list = await all();
    if (list.any((f) => f.id == fav.id)) return;
    list.add(fav);
    await _persist(list);
    unawaited(_syncCloudAdd(fav));
    _log.info('+ ${fav.name}');
  }

  Future<void> remove(String id) async {
    final list = await all();
    list.removeWhere((f) => f.id == id);
    await _persist(list);
    unawaited(_syncCloudRemove(id));
    _log.info('- $id');
  }

  Future<void> _persist(List<FavoriteNeighborhood> list) async {
    final prefs = await _prefs();
    await prefs.setString(
      _prefsKey,
      jsonEncode(list.map((f) => f.toJson()).toList()),
    );
  }

  // ─── Sync cloud (só quando user não-anônimo) ──────────────────────────

  CollectionReference<Map<String, dynamic>>? _cloudCollection() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) return null;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('favorites');
  }

  Future<void> _syncCloudAdd(FavoriteNeighborhood fav) async {
    final col = _cloudCollection();
    if (col == null) return;
    try {
      await col.doc(fav.id).set({
        ...fav.toJson(),
        'addedAt': FieldValue.serverTimestamp(),
      });
    } catch (e, s) {
      _log.error('cloud add falhou', e, s);
    }
  }

  Future<void> _syncCloudRemove(String id) async {
    final col = _cloudCollection();
    if (col == null) return;
    try {
      await col.doc(id).delete();
    } catch (e, s) {
      _log.error('cloud remove falhou', e, s);
    }
  }

  /// Pull on login — após user entrar com Google, baixa favoritos
  /// salvos no cloud e merge com os locais.
  Future<void> pullFromCloud() async {
    final col = _cloudCollection();
    if (col == null) return;
    try {
      final snap = await col.get();
      if (snap.docs.isEmpty) return;
      final remote = snap.docs.map((d) {
        final data = d.data();
        final addedAt = data['addedAt'];
        DateTime parsedAddedAt;
        if (addedAt is Timestamp) {
          parsedAddedAt = addedAt.toDate();
        } else if (addedAt is String) {
          parsedAddedAt = DateTime.tryParse(addedAt) ?? DateTime.now();
        } else {
          parsedAddedAt = DateTime.now();
        }
        return FavoriteNeighborhood(
          id: d.id,
          name: data['name'] as String? ?? d.id,
          city: data['city'] as String?,
          centroidLat: (data['lat'] as num?)?.toDouble() ?? 0,
          centroidLng: (data['lng'] as num?)?.toDouble() ?? 0,
          addedAt: parsedAddedAt,
        );
      }).toList();

      // Merge: cloud é fonte de verdade quando user está logado.
      // (Cenário "criei local antes de logar" é coberto porque após o
      // primeiro add, o sync push manda pra cloud — fica reconciliado.)
      await _persist(remote);
      _log.info('pulled ${remote.length} favoritos do cloud');
    } catch (e, s) {
      _log.error('cloud pull falhou', e, s);
    }
  }
}

final favoritesServiceProvider = Provider<FavoritesService>(
  (_) => FavoritesService.instance,
);

final favoritesProvider = FutureProvider<List<FavoriteNeighborhood>>(
  (ref) => ref.watch(favoritesServiceProvider).all(),
);
