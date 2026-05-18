import 'dart:convert';

/// Cruzamento registrado entre o usuário e uma zona com relatos recentes.
///
/// Gravado **localmente** no device (SharedPreferences) toda vez que o
/// BackgroundLocationService detecta entrada em região com >= 1 relato
/// nas últimas 24h. NUNCA é enviado pro servidor — privacidade por design.
///
/// Lifecycle: limpeza automática quando passa de 7 dias.
class CrossingEvent {
  /// Identificador estável: timestamp em ms.
  final int id;
  final DateTime at;
  final String? neighborhood;
  final String? city;
  /// Contagem de relatos ativos na janela quando o cruzamento aconteceu.
  final int reportCount;
  /// Top 3 tipos predominantes (ex.: "Roubo", "Tiroteio", "Operação policial").
  final List<String> topReasons;
  /// IDs dos relatos que estavam ativos no momento — permite reabrir
  /// detalhe a partir do histórico.
  final List<String> occurrenceIds;

  const CrossingEvent({
    required this.id,
    required this.at,
    required this.neighborhood,
    required this.city,
    required this.reportCount,
    required this.topReasons,
    required this.occurrenceIds,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'at': at.toUtc().toIso8601String(),
        'neighborhood': neighborhood,
        'city': city,
        'reportCount': reportCount,
        'topReasons': topReasons,
        'occurrenceIds': occurrenceIds,
      };

  factory CrossingEvent.fromMap(Map<String, dynamic> m) => CrossingEvent(
        id: (m['id'] as num).toInt(),
        at: DateTime.parse(m['at'] as String).toLocal(),
        neighborhood: m['neighborhood'] as String?,
        city: m['city'] as String?,
        reportCount: (m['reportCount'] as num).toInt(),
        topReasons: (m['topReasons'] as List).whereType<String>().toList(),
        occurrenceIds: (m['occurrenceIds'] as List).whereType<String>().toList(),
      );

  String toJson() => jsonEncode(toMap());
  factory CrossingEvent.fromJson(String s) =>
      CrossingEvent.fromMap(jsonDecode(s) as Map<String, dynamic>);
}
