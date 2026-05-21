library;

import '../../models/occurrence.dart';

class AreaActivity {
  final String name;
  final int count;
  /// Centroide aproximado da área = média de lat/lng das ocorrências.
  /// É uma aproximação, NÃO a fronteira oficial do bairro.
  final double centroidLat;
  final double centroidLng;
  /// Breakdown por tipo de relato, ordenado desc por contagem.
  final List<MapEntry<String, int>> reasonBreakdown;
  final DateTime mostRecent;
  /// Cidade e estado representativos do bairro — extraídos das ocorrências
  /// (modo). Usados pra montar a chave de baseline histórico, que precisa
  /// dos 3 níveis pra distinguir bairros homônimos em cidades diferentes.
  final String? city;
  final String? state;

  AreaActivity({
    required this.name,
    required this.count,
    required this.centroidLat,
    required this.centroidLng,
    required this.reasonBreakdown,
    required this.mostRecent,
    this.city,
    this.state,
  });
}

/// Agrega ocorrências por bairro e retorna as top [topN] áreas com
/// pelo menos [minCount] relatos. Editorialmente, threshold mínimo
/// previne que bairro com 1 relato aleatório apareça em lista de "top
/// movimentação".
List<AreaActivity> rankAreas(
  List<Occurrence> occurrences, {
  int topN = 5,
  int minCount = 5,
}) {
  final byArea = <String, List<Occurrence>>{};
  for (final o in occurrences) {
    final name = o.neighborhood;
    if (name == null || name.isEmpty) continue;
    byArea.putIfAbsent(name, () => []).add(o);
  }

  final activities = <AreaActivity>[];
  for (final entry in byArea.entries) {
    final list = entry.value;
    if (list.length < minCount) continue;

    final lat = list.map((o) => o.latitude).fold(0.0, (a, b) => a + b) / list.length;
    final lng = list.map((o) => o.longitude).fold(0.0, (a, b) => a + b) / list.length;

    final byReason = <String, int>{};
    for (final o in list) {
      final r = o.mainReason ?? 'Não categorizado';
      byReason[r] = (byReason[r] ?? 0) + 1;
    }
    final breakdown = byReason.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final mostRecent = list.map((o) => o.date).reduce((a, b) => a.isAfter(b) ? a : b);

    activities.add(AreaActivity(
      name: entry.key,
      count: list.length,
      centroidLat: lat,
      centroidLng: lng,
      reasonBreakdown: breakdown,
      mostRecent: mostRecent,
      city: _modeOrNull(list.map((o) => o.city)),
      state: _modeOrNull(list.map((o) => o.state)),
    ));
  }

  activities.sort((a, b) => b.count.compareTo(a.count));
  return activities.take(topN).toList();
}

String? _modeOrNull(Iterable<String?> values) {
  final counts = <String, int>{};
  for (final v in values) {
    if (v == null || v.isEmpty) continue;
    counts[v] = (counts[v] ?? 0) + 1;
  }
  if (counts.isEmpty) return null;
  return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
}
