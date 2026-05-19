library;

import '../../models/occurrence.dart';

/// Agregação de ocorrências em transporte público (ônibus / metrô) por
/// bairro. Diferente de [AreaActivity] porque expõe a contagem por modal
/// e tolera volume baixo (minCount=1 por default) — eventos em transporte
/// são esparsos e mesmo 1 ocorrência num bairro é útil pra um turista
/// decidir entre Uber ou ônibus.
class TransportAreaActivity {
  final String neighborhood;
  final String? city;
  final int count;
  final int onibusCount;
  final int metroCount;
  /// Centroide médio das ocorrências (aproximado — não é fronteira oficial).
  final double centroidLat;
  final double centroidLng;
  /// Categorias de relato ordenadas desc por contagem ("Roubo · Agressão").
  final List<MapEntry<String, int>> reasonBreakdown;
  final DateTime mostRecent;

  TransportAreaActivity({
    required this.neighborhood,
    required this.city,
    required this.count,
    required this.onibusCount,
    required this.metroCount,
    required this.centroidLat,
    required this.centroidLng,
    required this.reasonBreakdown,
    required this.mostRecent,
  });
}

/// Filtra ocorrências por modal (ônibus/metrô/ambos) e agrupa por bairro.
///
/// - [modal] = `'onibus'`, `'metro'`, ou `null` (pega ambos).
/// - [minCount] default 1 — em transporte, 1 evento já é informação útil
///   pra alguém decidir trocar de modal.
List<TransportAreaActivity> rankTransportAreas(
  List<Occurrence> occurrences, {
  String? modal,
  int topN = 20,
  int minCount = 1,
}) {
  // Filtro: tem transportContext (= relato em transporte público) e bate
  // o modal pedido (se houver).
  final filtered = occurrences.where((o) {
    final ctx = o.transportContext;
    if (ctx == null) return false;
    if (modal != null && ctx != modal) return false;
    return true;
  }).toList();

  final byArea = <String, List<Occurrence>>{};
  for (final o in filtered) {
    final name = o.neighborhood;
    if (name == null || name.isEmpty) continue;
    byArea.putIfAbsent(name, () => []).add(o);
  }

  final activities = <TransportAreaActivity>[];
  for (final entry in byArea.entries) {
    final list = entry.value;
    if (list.length < minCount) continue;

    final lat = list.map((o) => o.latitude).fold(0.0, (a, b) => a + b) / list.length;
    final lng = list.map((o) => o.longitude).fold(0.0, (a, b) => a + b) / list.length;

    var bus = 0;
    var metro = 0;
    final byReason = <String, int>{};
    for (final o in list) {
      if (o.transportContext == 'onibus') bus++;
      if (o.transportContext == 'metro') metro++;
      final r = o.mainReason ?? 'Não categorizado';
      byReason[r] = (byReason[r] ?? 0) + 1;
    }
    final breakdown = byReason.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final mostRecent =
        list.map((o) => o.date).reduce((a, b) => a.isAfter(b) ? a : b);

    activities.add(TransportAreaActivity(
      neighborhood: entry.key,
      city: list.first.city,
      count: list.length,
      onibusCount: bus,
      metroCount: metro,
      centroidLat: lat,
      centroidLng: lng,
      reasonBreakdown: breakdown,
      mostRecent: mostRecent,
    ));
  }

  activities.sort((a, b) => b.count.compareTo(a.count));
  return activities.take(topN).toList();
}

/// Contagem global por modal — usada nos chips do filtro.
({int bus, int metro}) countByModal(List<Occurrence> occurrences) {
  var bus = 0;
  var metro = 0;
  for (final o in occurrences) {
    if (o.transportContext == 'onibus') bus++;
    if (o.transportContext == 'metro') metro++;
  }
  return (bus: bus, metro: metro);
}
