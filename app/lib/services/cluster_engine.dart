library;

import 'dart:math' as math;

import '../core/theme/app_theme.dart';
import '../models/occurrence.dart';
import 'marker_factory.dart' show classifyAge;

/// Nó do mapa pós-clustering. Pode ser um relato isolado ou um cluster
/// agregando vários relatos próximos no mesmo zoom.
class MapNode {
  final double lat;
  final double lng;
  final List<Occurrence> members;

  MapNode(this.lat, this.lng, this.members);

  bool get isCluster => members.length > 1;
  int get count => members.length;

  /// Cluster herda o risco do relato mais recente (maior RiskLevel).
  RiskLevel get risk {
    var max = RiskLevel.noRecentReports;
    for (final m in members) {
      final r = classifyAge(m.date);
      if (r.index > max.index) max = r;
    }
    return max;
  }
}

/// Zoom abaixo do qual o mapa mostra heatmap (zoom-out, panorâmica).
/// Acima, marcadores individuais ou clusters.
const double kHeatmapZoomThreshold = 14.5;

/// Zoom acima do qual paramos de agrupar — street-level, cada relato
/// vira seu próprio marcador.
const double kClusterCeilingZoom = 17.0;

/// Agrupa ocorrências em nós pra um dado zoom.
///
/// - Em zoom < [heatmapZoomThreshold] ou em zoom >= [clusterCeilingZoom],
///   cada ocorrência vira seu próprio nó (sem agregar).
/// - Entre os dois, células de ~[clusterCellPixels] pixels na tela agrupam
///   relatos próximos; cada cluster recebe centroide simples (média).
///
/// [referenceLat] entra no cálculo de metros/pixel — em Salvador (~-12.97°)
/// a diferença latitudinal é pequena, então usar a latitude do centro do
/// mapa é suficiente.
List<MapNode> clusterOccurrences({
  required List<Occurrence> occurrences,
  required double zoom,
  required double referenceLat,
  double clusterCellPixels = 80,
  double heatmapZoomThreshold = kHeatmapZoomThreshold,
  double clusterCeilingZoom = kClusterCeilingZoom,
}) {
  final shouldCluster = zoom >= heatmapZoomThreshold && zoom < clusterCeilingZoom;
  if (!shouldCluster || occurrences.isEmpty) {
    return [for (final o in occurrences) MapNode(o.latitude, o.longitude, [o])];
  }

  // 1° de latitude ≈ 111320m. Em zoom Z: 156543 * cos(lat) / 2^Z m/pixel.
  final metersPerPixel =
      156543.034 * math.cos(referenceLat * math.pi / 180.0) / math.pow(2, zoom);
  final cellMeters = clusterCellPixels * metersPerPixel;
  final cellDeg = cellMeters / 111320.0;

  final cells = <String, List<Occurrence>>{};
  for (final o in occurrences) {
    final key = '${(o.latitude / cellDeg).floor()},${(o.longitude / cellDeg).floor()}';
    cells.putIfAbsent(key, () => []).add(o);
  }

  final nodes = <MapNode>[];
  for (final group in cells.values) {
    if (group.length == 1) {
      final o = group.first;
      nodes.add(MapNode(o.latitude, o.longitude, group));
    } else {
      final lat = group.fold(0.0, (a, o) => a + o.latitude) / group.length;
      final lng = group.fold(0.0, (a, o) => a + o.longitude) / group.length;
      nodes.add(MapNode(lat, lng, group));
    }
  }
  return nodes;
}
