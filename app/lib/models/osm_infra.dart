import 'package:cloud_firestore/cloud_firestore.dart';

/// Categorias de infraestrutura urbana ingeridas via Cloud Function
/// `fetchOsmInfra`. Cada doc fica em `/osm/{kind}` e devolve uma lista de
/// [OsmInfra] que o app exibe como camadas opcionais no mapa.
///
/// Editorial: cada camada é contexto, nunca veredito. "Tem delegacia aqui"
/// é informação; "área segura" seria julgamento — não fazemos isso.
enum OsmInfraKind {
  police,
  hospitals,
  streetLamps,
  commerce24h;

  String get firestoreId {
    switch (this) {
      case OsmInfraKind.police:
        return 'police';
      case OsmInfraKind.hospitals:
        return 'hospitals';
      case OsmInfraKind.streetLamps:
        return 'street_lamps';
      case OsmInfraKind.commerce24h:
        return 'commerce_24h';
    }
  }
}

/// Item de infraestrutura urbana (delegacia, hospital, poste, comércio 24h).
/// Os campos opcionais variam por categoria — ver `tagSubset` no backend.
class OsmInfra {
  final int id;
  final String type;
  final double lat;
  final double lng;
  final String? name;
  final String? phone;
  final String? operator;
  final bool? emergency;
  final String? shop;
  final String? amenity;
  final String? brand;

  const OsmInfra({
    required this.id,
    required this.type,
    required this.lat,
    required this.lng,
    this.name,
    this.phone,
    this.operator,
    this.emergency,
    this.shop,
    this.amenity,
    this.brand,
  });

  factory OsmInfra.fromMap(Map<String, dynamic> m) => OsmInfra(
        id: (m['id'] as num).toInt(),
        type: (m['type'] as String?) ?? 'node',
        lat: (m['lat'] as num).toDouble(),
        lng: (m['lng'] as num).toDouble(),
        name: m['name'] as String?,
        phone: m['phone'] as String?,
        operator: m['operator'] as String?,
        emergency: m['emergency'] as bool?,
        shop: m['shop'] as String?,
        amenity: m['amenity'] as String?,
        brand: m['brand'] as String?,
      );

  /// Lê a lista do doc `/osm/{kind}` (campo `items`). Aceita também o
  /// campo legado `stops` pra compatibilidade com snapshots antigos.
  static List<OsmInfra> listFromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) return const [];
    final raw = data['items'] ?? data['stops'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(OsmInfra.fromMap)
        .toList(growable: false);
  }
}
