import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/bus_stop.dart';
import 'occurrences_service.dart' show firestoreProvider;

/// Lê o snapshot de pontos de ônibus gravado pela Cloud Function
/// `fetchOsmBusStops`. Doc único `/osm/bus_stops` com array `stops`.
///
/// Carregamento lazy: só é disparado quando o usuário ativa o toggle
/// no mapa. Resultado fica em cache na vida do provider (autoDispose=false).
class OsmService {
  final FirebaseFirestore _db;
  OsmService(this._db);

  Future<List<BusStop>> loadBusStops() async {
    final snap = await _db.collection('osm').doc('bus_stops').get();
    if (!snap.exists) return const [];
    return BusStop.listFromDoc(snap);
  }
}

final osmServiceProvider = Provider<OsmService>(
  (ref) => OsmService(ref.watch(firestoreProvider)),
);

/// Lazy: só carrega quando alguém assiste.
final busStopsProvider = FutureProvider<List<BusStop>>(
  (ref) => ref.watch(osmServiceProvider).loadBusStops(),
);
