import 'package:cloud_firestore/cloud_firestore.dart';

class Occurrence {
  final String id;
  final double latitude;
  final double longitude;
  final DateTime date;
  final String? state;
  final String? city;
  final String? neighborhood;
  final String? mainReason;
  final String source;
  final double weight;
  final DateTime? expiresAt;

  Occurrence({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.date,
    this.state,
    this.city,
    this.neighborhood,
    this.mainReason,
    this.source = 'unknown',
    this.weight = 0.5,
    this.expiresAt,
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
      source: d['source'] as String? ?? 'unknown',
      weight: (d['weight'] as num?)?.toDouble() ?? 0.5,
      expiresAt: (d['expiresAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'latitude': latitude,
        'longitude': longitude,
        'date': Timestamp.fromDate(date),
        'state': state,
        'city': city,
        'neighborhood': neighborhood,
        'mainReason': mainReason,
        'source': source,
        'weight': weight,
        if (expiresAt != null) 'expiresAt': Timestamp.fromDate(expiresAt!),
      };
}
