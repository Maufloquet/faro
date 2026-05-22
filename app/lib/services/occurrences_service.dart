import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/occurrence.dart';

/// Estado padrão das queries no MVP. Faro é focado em Salvador/RMS, então
/// puxar 500 relatos globalmente trazia ruído de outros estados quando a
/// Camada 2 começou a ingerir RJ/PE/SP. Quando virar multi-estado de
/// verdade (V2), trocar pra selector na UI + param dinâmico no provider.
const String kDefaultOccurrenceState = 'Bahia';

class OccurrencesService {
  final FirebaseFirestore _db;
  OccurrencesService(this._db);

  /// Stream das ocorrências mais recentes filtradas por estado.
  ///
  /// Janela default 30 dias — alinhada ao TTL gravado pela Cloud Function.
  /// O filtro TimeWindow do app (Hoje/7d/30d/Tudo) é aplicado client-side
  /// em cima desse pool, então 30 dias é o teto natural pro \"Tudo\".
  ///
  /// `stateName` filtra server-side via índice (state ASC, date DESC) já
  /// deployado. Default editorial é Bahia — outros estados são pulled in
  /// só quando o cliente passar explicitamente. Filtros geográficos
  /// finos (raio, viewport) continuam client-side, ver `_passesRegionFilter`
  /// em map_screen.dart.
  Stream<List<Occurrence>> recent({
    Duration window = const Duration(days: 30),
    String stateName = kDefaultOccurrenceState,
  }) {
    final cutoff = DateTime.now().subtract(window);
    return _db
        .collection('occurrences')
        .where('state', isEqualTo: stateName)
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
