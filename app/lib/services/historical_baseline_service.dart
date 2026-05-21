import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/historical_baseline.dart';
import 'occurrences_service.dart' show firestoreProvider;

/// Lê snapshots agregados de `/historical_baseline/{regionKey}`. O backend
/// (`aggregateHistoricalBaseline`) escreve 1x/dia.
///
/// Carregamento lazy: cada bairro vira um lookup separado e cacheado pelo
/// Riverpod via `FutureProvider.family`. UI pode chamar pra um bairro de
/// cada vez sem precisar carregar a coleção inteira.
class HistoricalBaselineService {
  final FirebaseFirestore _db;
  HistoricalBaselineService(this._db);

  Future<HistoricalBaseline?> load({
    String? state,
    String? city,
    required String neighborhood,
  }) async {
    final key = baselineRegionKey(
      state: state,
      city: city,
      neighborhood: neighborhood,
    );
    final snap = await _db.collection('historical_baseline').doc(key).get();
    if (!snap.exists) return null;
    return HistoricalBaseline.fromDoc(snap);
  }
}

final historicalBaselineServiceProvider =
    Provider<HistoricalBaselineService>(
  (ref) => HistoricalBaselineService(ref.watch(firestoreProvider)),
);

/// Argumento usado pelo provider família — encapsula o trio que define
/// a chave (state pode ser omitido, fallback "_").
class BaselineLookup {
  final String? state;
  final String? city;
  final String neighborhood;
  const BaselineLookup({
    this.state,
    this.city,
    required this.neighborhood,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BaselineLookup &&
          other.state == state &&
          other.city == city &&
          other.neighborhood == neighborhood);

  @override
  int get hashCode => Object.hash(state, city, neighborhood);
}

final baselineProvider =
    FutureProvider.family<HistoricalBaseline?, BaselineLookup>(
  (ref, lookup) => ref.watch(historicalBaselineServiceProvider).load(
        state: lookup.state,
        city: lookup.city,
        neighborhood: lookup.neighborhood,
      ),
);
