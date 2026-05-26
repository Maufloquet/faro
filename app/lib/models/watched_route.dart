import 'package:cloud_firestore/cloud_firestore.dart';

/// Trajeto observado: origem→destino que o usuário pediu pra ser avisado
/// quando aparecer relato novo no corredor (scheduler watchRoutes).
/// Vive em /users/{uid}/watchedRoutes/{id}.
class WatchedRoute {
  final String id;
  final String label;
  final double originLat;
  final double originLng;
  final double destLat;
  final double destLng;
  final double corridorMeters;
  final bool active;
  final DateTime? createdAt;
  final DateTime? lastCheckedAt;

  const WatchedRoute({
    required this.id,
    required this.label,
    required this.originLat,
    required this.originLng,
    required this.destLat,
    required this.destLng,
    this.corridorMeters = 500,
    this.active = true,
    this.createdAt,
    this.lastCheckedAt,
  });

  factory WatchedRoute.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return WatchedRoute(
      id: doc.id,
      label: (d['label'] as String?) ?? 'Trajeto',
      originLat: (d['originLat'] as num).toDouble(),
      originLng: (d['originLng'] as num).toDouble(),
      destLat: (d['destLat'] as num).toDouble(),
      destLng: (d['destLng'] as num).toDouble(),
      corridorMeters: (d['corridorMeters'] as num?)?.toDouble() ?? 500,
      active: d['active'] != false,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      lastCheckedAt: (d['lastCheckedAt'] as Timestamp?)?.toDate(),
    );
  }
}
