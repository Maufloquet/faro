import 'package:cloud_firestore/cloud_firestore.dart';

enum OccurrenceSource {
  fogoCruzado,
  media,
  userReport,
  unknown;

  static OccurrenceSource parse(String? raw) {
    switch (raw) {
      case 'fogo_cruzado':
        return OccurrenceSource.fogoCruzado;
      case 'media':
        return OccurrenceSource.media;
      case 'user_report':
        return OccurrenceSource.userReport;
      default:
        return OccurrenceSource.unknown;
    }
  }

  String get displayName {
    switch (this) {
      case OccurrenceSource.fogoCruzado:
        return 'Fogo Cruzado';
      case OccurrenceSource.media:
        return 'Mídia';
      case OccurrenceSource.userReport:
        return 'Relato de usuário';
      case OccurrenceSource.unknown:
        return 'Origem desconhecida';
    }
  }
}

class Occurrence {
  final String id;
  final double latitude;
  final double longitude;
  final DateTime date;
  final String? state;
  final String? city;
  final String? neighborhood;
  final String? mainReason;
  final OccurrenceSource source;
  final double weight;
  final DateTime? expiresAt;
  // Campos específicos do source=media:
  final String? sourceProvider;
  final String? sourceName;
  final String? externalUrl;
  final String? externalTitle;
  final double? confidence;
  final String? geocodeMethod;

  bool get isCityCentroid => geocodeMethod == 'city-centroid';

  Occurrence({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.date,
    this.state,
    this.city,
    this.neighborhood,
    this.mainReason,
    this.source = OccurrenceSource.unknown,
    this.weight = 0.5,
    this.expiresAt,
    this.sourceProvider,
    this.sourceName,
    this.externalUrl,
    this.externalTitle,
    this.confidence,
    this.geocodeMethod,
  });

  factory Occurrence.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Occurrence(
      id: doc.id,
      latitude: (d['latitude'] as num).toDouble(),
      longitude: (d['longitude'] as num).toDouble(),
      date: (d['date'] as Timestamp).toDate(),
      state: d['state'] as String?,
      city: d['city'] as String?,
      neighborhood: d['neighborhood'] as String?,
      mainReason: d['mainReason'] as String?,
      source: OccurrenceSource.parse(d['source'] as String?),
      weight: (d['weight'] as num?)?.toDouble() ?? 0.5,
      expiresAt: (d['expiresAt'] as Timestamp?)?.toDate(),
      sourceProvider: d['sourceProvider'] as String?,
      sourceName: d['sourceName'] as String?,
      externalUrl: d['externalUrl'] as String?,
      externalTitle: d['externalTitle'] as String?,
      confidence: (d['confidence'] as num?)?.toDouble(),
      geocodeMethod: d['geocodeMethod'] as String?,
    );
  }
}
