import 'package:cloud_firestore/cloud_firestore.dart';

/// Ponto de ônibus extraído do OpenStreetMap via Cloud Function `fetchOsmBusStops`.
///
/// Estrutura fiel ao output de `osmFetch.parseBusStops` no backend. Tags
/// editorialmente relevantes pra audiência "passageiro de ônibus":
/// `shelter` (cobertura), `bench`, `lit` (iluminação).
class BusStop {
  final int id;
  final double lat;
  final double lng;
  final String? name;
  final bool shelter;
  final bool bench;
  final bool lit;

  const BusStop({
    required this.id,
    required this.lat,
    required this.lng,
    this.name,
    this.shelter = false,
    this.bench = false,
    this.lit = false,
  });

  factory BusStop.fromMap(Map<String, dynamic> m) => BusStop(
        id: (m['id'] as num).toInt(),
        lat: (m['lat'] as num).toDouble(),
        lng: (m['lng'] as num).toDouble(),
        name: m['name'] as String?,
        shelter: m['shelter'] == true,
        bench: m['bench'] == true,
        lit: m['lit'] == true,
      );

  /// Constrói lista a partir do doc /osm/bus_stops do Firestore.
  static List<BusStop> listFromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) return const [];
    final raw = data['stops'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(BusStop.fromMap)
        .toList(growable: false);
  }
}
