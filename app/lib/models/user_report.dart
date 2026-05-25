import 'package:cloud_firestore/cloud_firestore.dart';

/// Tipo de relato que o usuário pode abrir. O `id` casa com o vocabulário
/// de `occurrence_type` do pipeline de notícias (newsIngest TYPE_MAP), pra
/// que um relato confirmado seja promovido a /occurrences sem tradução.
enum ReportType {
  tiroteio('tiroteio', 'Tiroteio ou disparo'),
  roubo('roubo', 'Roubo ou assalto'),
  homicidio('homicidio', 'Homicídio'),
  agressao('agressao', 'Agressão'),
  acaoPolicial('acao_policial', 'Movimentação policial'),
  outros('outros', 'Outra coisa');

  const ReportType(this.id, this.label);
  final String id;
  final String label;

  static ReportType parse(String? raw) {
    for (final t in ReportType.values) {
      if (t.id == raw) return t;
    }
    return ReportType.outros;
  }
}

/// Estado de um relato na caixa de entrada /reports.
///   - pending: aguardando validação coletiva
///   - confirmed: atingiu o limiar de confirmações (promovido a ocorrência)
///   - rejected: contestado o bastante pra ser escondido
///   - expired: ninguém confirmou dentro da janela (some do mapa)
enum ReportStatus {
  pending,
  confirmed,
  rejected,
  expired,
  unknown;

  static ReportStatus parse(String? raw) {
    switch (raw) {
      case 'pending':
        return ReportStatus.pending;
      case 'confirmed':
        return ReportStatus.confirmed;
      case 'rejected':
        return ReportStatus.rejected;
      case 'expired':
        return ReportStatus.expired;
      default:
        return ReportStatus.unknown;
    }
  }
}

/// Relato aberto por um usuário. Vive em /reports até ser validado.
class UserReport {
  final String id;
  final double lat;
  final double lng;
  final ReportType type;
  final String? description;
  final String? city;
  final String? neighborhood;
  final String createdBy;
  final DateTime? createdAt;
  final DateTime? expiresAt;
  final ReportStatus status;
  final int confirmCount;
  final int contestCount;

  const UserReport({
    required this.id,
    required this.lat,
    required this.lng,
    required this.type,
    required this.createdBy,
    this.description,
    this.city,
    this.neighborhood,
    this.createdAt,
    this.expiresAt,
    this.status = ReportStatus.pending,
    this.confirmCount = 0,
    this.contestCount = 0,
  });

  factory UserReport.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return UserReport(
      id: doc.id,
      lat: (d['lat'] as num).toDouble(),
      lng: (d['lng'] as num).toDouble(),
      type: ReportType.parse(d['type'] as String?),
      description: d['description'] as String?,
      city: d['city'] as String?,
      neighborhood: d['neighborhood'] as String?,
      createdBy: (d['createdBy'] as String?) ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      expiresAt: (d['expiresAt'] as Timestamp?)?.toDate(),
      status: ReportStatus.parse(d['status'] as String?),
      confirmCount: (d['confirmCount'] as num?)?.toInt() ?? 0,
      contestCount: (d['contestCount'] as num?)?.toInt() ?? 0,
    );
  }
}
