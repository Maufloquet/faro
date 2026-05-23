import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/log/faro_logger.dart';
import '../models/admin_metrics.dart';
import '../models/job_health.dart';

/// Camada de leitura do painel admin.
///
/// Lê o doc `/admin_metrics/current` mantido pela Cloud Function
/// `aggregateAdminMetrics` (scheduler a cada 30 min). As Firestore rules
/// barram a leitura pra qualquer usuário sem o custom claim `admin`,
/// então o gate de segurança vive no servidor — o cliente só decide se
/// mostra ou esconde a UI.
class AdminMetricsService {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  static const _log = FaroLogger('admin');

  AdminMetricsService({FirebaseFirestore? db, FirebaseAuth? auth})
      : _db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  /// Stream do doc `/admin_metrics/current`. Reemite a cada nova
  /// agregação do scheduler. Erros (incluindo permission-denied) sobem
  /// como `AsyncError` no provider que escuta.
  Stream<AdminMetrics> watchCurrent() => _db
      .collection('admin_metrics')
      .doc('current')
      .snapshots()
      .map(AdminMetrics.fromDoc);

  /// Stream da collection `/system_health` — um doc por scheduler com o
  /// último resultado do run. Ordena pelo nome pra UI estável.
  Stream<List<JobHealth>> watchJobHealth() => _db
      .collection('system_health')
      .snapshots()
      .map((snap) => snap.docs.map(JobHealth.fromDoc).toList()
        ..sort((a, b) => a.name.compareTo(b.name)));

  /// Confirma se o usuário corrente tem o claim `admin: true`.
  ///
  /// Força refresh do token (`getIdTokenResult(true)`) — custom claims
  /// só entram no token via refresh, e o token tem TTL de 1h. Sem
  /// refresh, o usuário recém-promovido teria que esperar até 1h ou
  /// fazer logout/login. Aqui pagamos uma round-trip pra UX imediata.
  Future<bool> isCurrentUserAdmin() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    try {
      final token = await user.getIdTokenResult(true);
      final claim = token.claims?['admin'];
      return claim == true;
    } catch (e, s) {
      _log.error('refresh de claim admin falhou', e, s);
      return false;
    }
  }
}

final adminMetricsServiceProvider = Provider<AdminMetricsService>(
  (_) => AdminMetricsService(),
);

/// Stream reativo do snapshot atual. UI assiste via `ref.watch`.
final adminMetricsProvider = StreamProvider<AdminMetrics>((ref) {
  return ref.watch(adminMetricsServiceProvider).watchCurrent();
});

/// Stream do grid de saúde dos schedulers.
final jobHealthProvider = StreamProvider<List<JobHealth>>((ref) {
  return ref.watch(adminMetricsServiceProvider).watchJobHealth();
});

/// Future que resolve `true` se o usuário corrente é admin. Faz refresh
/// forçado do token, então é cara — não chame em build, prefira
/// `ref.watch` num FutureProvider que cacheia.
final isAdminProvider = FutureProvider<bool>((ref) {
  return ref.watch(adminMetricsServiceProvider).isCurrentUserAdmin();
});
