import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/route_plan.dart';
import '../models/watched_route.dart';

/// CRUD de trajetos observados (V2 da rota A→B). Os alertas em si vêm do
/// scheduler `watchRoutes` no servidor.
class WatchedRouteService {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  WatchedRouteService(this._db, this._auth);

  CollectionReference<Map<String, dynamic>>? _col() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    return _db.collection('users').doc(uid).collection('watchedRoutes');
  }

  /// Salva um trajeto a partir de um RoutePlan. `lastCheckedAt` começa em
  /// agora — o scheduler só alerta o que entrar no corredor a partir daqui.
  Future<void> save(RoutePlan plan) async {
    final col = _col();
    if (col == null) {
      throw const WatchedRouteException('Sem identificação. Tente de novo.');
    }
    final label =
        '${plan.originLabel ?? 'Origem'} → ${plan.destinationLabel ?? 'Destino'}';
    await col.add({
      'label': label,
      'originLat': plan.originLat,
      'originLng': plan.originLng,
      'destLat': plan.destinationLat,
      'destLng': plan.destinationLng,
      'corridorMeters': plan.corridorKm * 1000,
      'active': true,
      'createdAt': FieldValue.serverTimestamp(),
      'lastCheckedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<WatchedRoute>> watchAll() {
    final col = _col();
    if (col == null) return Stream.value(const []);
    return col.snapshots().map(
          (snap) => snap.docs.map(WatchedRoute.fromFirestore).toList(),
        );
  }

  Future<void> remove(String routeId) async {
    final col = _col();
    if (col == null) return;
    await col.doc(routeId).delete();
  }
}

class WatchedRouteException implements Exception {
  final String message;
  const WatchedRouteException(this.message);
  @override
  String toString() => message;
}

final watchedRouteServiceProvider = Provider<WatchedRouteService>(
  (_) => WatchedRouteService(FirebaseFirestore.instance, FirebaseAuth.instance),
);

final watchedRoutesProvider = StreamProvider<List<WatchedRoute>>(
  (ref) => ref.watch(watchedRouteServiceProvider).watchAll(),
);
