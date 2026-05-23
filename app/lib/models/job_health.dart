import 'package:cloud_firestore/cloud_firestore.dart';

/// Heartbeat de um scheduler escrito pelo helper `jobHealth.runWithHealth`
/// no fim de cada run (`functions/lib/jobHealth.js`). Snapshot lido pelo
/// painel admin pra renderizar o grid de saúde.
class JobHealth {
  final String name;
  final JobStatus status;
  final DateTime? lastRunAt;
  final DateTime? lastSuccessAt;
  final String? lastError;
  final int? itemsWritten;
  final int? durationMs;

  const JobHealth({
    required this.name,
    required this.status,
    required this.lastRunAt,
    required this.lastSuccessAt,
    required this.lastError,
    required this.itemsWritten,
    required this.durationMs,
  });

  factory JobHealth.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? const {};
    return JobHealth(
      name: (data['name'] as String?) ?? doc.id,
      status: JobStatus.fromString(data['lastStatus'] as String?),
      lastRunAt: _toDate(data['lastRunAt']),
      lastSuccessAt: _toDate(data['lastSuccessAt']),
      lastError: data['lastError'] as String?,
      itemsWritten: _asIntOrNull(data['itemsWritten']),
      durationMs: _asIntOrNull(data['durationMs']),
    );
  }

  /// Avalia o status visual considerando a frequência esperada do job.
  /// Verde: rodou ok dentro do intervalo. Amarelo: ok mas atrasado.
  /// Vermelho: último run falhou OU nunca rodou.
  JobHealthLevel level({required Duration expectedInterval, DateTime? now}) {
    final ts = now ?? DateTime.now();
    if (status == JobStatus.error) return JobHealthLevel.error;
    final since = lastRunAt;
    if (since == null) return JobHealthLevel.error;
    final age = ts.difference(since);
    // 2× o intervalo é a tolerância pra job atrasado mas não preocupante
    // (cron pode pular um tick em janela de manutenção).
    if (age > expectedInterval * 2) return JobHealthLevel.stale;
    return JobHealthLevel.ok;
  }
}

enum JobStatus {
  ok,
  error,
  unknown;

  static JobStatus fromString(String? s) {
    switch (s) {
      case 'ok':
        return JobStatus.ok;
      case 'error':
        return JobStatus.error;
      default:
        return JobStatus.unknown;
    }
  }
}

enum JobHealthLevel { ok, stale, error }

/// Tabela com a frequência esperada de cada cron, em sincronia com o
/// `schedule` declarado em `functions/lib/*.js`. Source of truth — quando
/// mudar o cron, mudar aqui também (idealmente teste pegaria divergência,
/// fica como TODO).
const Map<String, Duration> kJobIntervals = {
  'syncFogoCruzado': Duration(minutes: 30),
  'ingestNewsBahia': Duration(minutes: 30),
  'ingestOsmNotes': Duration(days: 1),
  'syncOsmInfra': Duration(days: 7),
  'cleanupOccurrences': Duration(days: 1),
  'aggregateHistoricalBaseline': Duration(days: 1),
  'aggregateAdminMetrics': Duration(minutes: 30),
};

DateTime? _toDate(Object? v) {
  if (v == null) return null;
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  return null;
}

int? _asIntOrNull(Object? v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return null;
}
