import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/occurrence.dart';

class OccurrencesService {
  final FirebaseFirestore _db;
  OccurrencesService(this._db);

  /// Stream das ocorrências mais recentes (últimas 24h por padrão).
  ///
  /// Filtros geográficos serão adicionados via geo-hash em V2 (ver
  /// docs/visao.md §2.6 e relatório v3 §9.2). Por enquanto retorna
  /// tudo da janela temporal.
  Stream<List<Occurrence>> recent({Duration window = const Duration(hours: 24)}) {
    final cutoff = DateTime.now().subtract(window);
    return _db
        .collection('occurrences')
        .where('date', isGreaterThan: Timestamp.fromDate(cutoff))
        .orderBy('date', descending: true)
        .limit(500)
        .snapshots()
        .map((snap) => snap.docs.map(Occurrence.fromFirestore).toList());
  }
}

final firestoreProvider = Provider<FirebaseFirestore>((_) => FirebaseFirestore.instance);
final occurrencesServiceProvider = Provider<OccurrencesService>(
  (ref) => OccurrencesService(ref.watch(firestoreProvider)),
);
final recentOccurrencesProvider = StreamProvider<List<Occurrence>>(
  (ref) => ref.watch(occurrencesServiceProvider).recent(),
);
