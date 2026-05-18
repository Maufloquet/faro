library;

import '../../models/occurrence.dart';

/// Agregado de quantas vezes uma linha de ônibus apareceu citada em
/// relatos do período. Editorialmente: cuidado pra **não** virar ranking
/// de "linha perigosa" — pessoa que usa o ônibus muitas vezes não pode
/// trocar. Esse dado serve pra **se preparar**, não pra evitar.
class BusLineActivity {
  final String line;
  final int count;
  final DateTime mostRecent;
  /// Bairros onde a linha foi citada (deduplicado, ordenado pela contagem).
  final List<MapEntry<String, int>> neighborhoodBreakdown;
  /// Tipos predominantes (roubo, agressão, etc.).
  final List<MapEntry<String, int>> reasonBreakdown;

  BusLineActivity({
    required this.line,
    required this.count,
    required this.mostRecent,
    required this.neighborhoodBreakdown,
    required this.reasonBreakdown,
  });
}

/// Agrega ocorrências por linha de ônibus citada. Cada ocorrência pode
/// estar associada a múltiplas linhas — todas contam.
///
/// [minCount] é o piso editorial: linha com 1 citação isolada não vira
/// item de lista (evita falar de linha por causa de uma matéria só).
List<BusLineActivity> rankBusLines(
  List<Occurrence> occurrences, {
  int topN = 10,
  int minCount = 2,
}) {
  final byLine = <String, List<Occurrence>>{};
  for (final o in occurrences) {
    for (final line in o.busLines) {
      if (line.isEmpty) continue;
      byLine.putIfAbsent(line, () => []).add(o);
    }
  }

  final activities = <BusLineActivity>[];
  for (final entry in byLine.entries) {
    final list = entry.value;
    if (list.length < minCount) continue;

    final byNeigh = <String, int>{};
    final byReason = <String, int>{};
    for (final o in list) {
      final n = o.neighborhood;
      if (n != null && n.isNotEmpty) {
        byNeigh[n] = (byNeigh[n] ?? 0) + 1;
      }
      final r = o.mainReason ?? 'Não categorizado';
      byReason[r] = (byReason[r] ?? 0) + 1;
    }
    final neighSorted = byNeigh.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final reasonSorted = byReason.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final mostRecent =
        list.map((o) => o.date).reduce((a, b) => a.isAfter(b) ? a : b);

    activities.add(BusLineActivity(
      line: entry.key,
      count: list.length,
      mostRecent: mostRecent,
      neighborhoodBreakdown: neighSorted,
      reasonBreakdown: reasonSorted,
    ));
  }

  activities.sort((a, b) => b.count.compareTo(a.count));
  return activities.take(topN).toList();
}
