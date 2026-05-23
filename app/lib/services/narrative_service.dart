import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/narrative.dart';

/// Leitura das narrativas ativas (`/narratives`). Ordenadas por contagem
/// — mais relatos no cluster, maior probabilidade de virar o card de
/// destaque na UI.
class NarrativeService {
  final FirebaseFirestore _db;

  NarrativeService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  Stream<List<Narrative>> watchActive({int limit = 5}) => _db
      .collection('narratives')
      .orderBy('count', descending: true)
      .limit(limit)
      .snapshots()
      .map((snap) => snap.docs.map(Narrative.fromDoc).toList());
}

final narrativeServiceProvider = Provider<NarrativeService>(
  (_) => NarrativeService(),
);

final activeNarrativesProvider = StreamProvider<List<Narrative>>((ref) {
  return ref.watch(narrativeServiceProvider).watchActive();
});
