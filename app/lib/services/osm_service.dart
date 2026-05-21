import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/bus_stop.dart';
import '../models/osm_infra.dart';
import 'occurrences_service.dart' show firestoreProvider;

/// Lê os snapshots de infraestrutura urbana gravados pelas Cloud Functions
/// `fetchOsmBusStops` (legado) e `fetchOsmInfra` (delegacias, hospitais,
/// postes, comércio 24h). Cada categoria vive em `/osm/{id}`.
///
/// Carregamento lazy: o provider só dispara quando alguém o assiste — o
/// usuário precisa ligar o toggle correspondente no sheet de camadas.
class OsmService {
  final FirebaseFirestore _db;
  OsmService(this._db);

  Future<List<BusStop>> loadBusStops() async {
    final snap = await _db.collection('osm').doc('bus_stops').get();
    if (!snap.exists) return const [];
    return BusStop.listFromDoc(snap);
  }

  Future<List<OsmInfra>> loadInfra(OsmInfraKind kind) async {
    final snap = await _db.collection('osm').doc(kind.firestoreId).get();
    if (!snap.exists) return const [];
    return OsmInfra.listFromDoc(snap);
  }
}

final osmServiceProvider = Provider<OsmService>(
  (ref) => OsmService(ref.watch(firestoreProvider)),
);

final busStopsProvider = FutureProvider<List<BusStop>>(
  (ref) => ref.watch(osmServiceProvider).loadBusStops(),
);

/// Provider família, indexado por categoria — cada toggle no UI assiste
/// só o provider da sua camada e o cache fica isolado.
final osmInfraProvider =
    FutureProvider.family<List<OsmInfra>, OsmInfraKind>(
  (ref, kind) => ref.watch(osmServiceProvider).loadInfra(kind),
);
