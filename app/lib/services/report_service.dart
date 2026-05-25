import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_report.dart';

/// Janela de vida de um relato não-confirmado. O cliente grava esse prazo
/// no `expiresAt`, mas a fonte de verdade da expiração é o scheduler
/// `expireReports` (Bloco 3) — aqui é só pra o cliente filtrar localmente
/// e pra a regra exigir o campo.
const Duration kReportTtl = Duration(hours: 4);

/// Escreve e lê relatos de usuário na coleção /reports (Camada 4).
class ReportService {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  ReportService(this._db, this._auth);

  /// Abre um relato. GPS é obrigatório — quem chama já resolveu a posição.
  /// Devolve o id do doc criado.
  Future<String> create({
    required double lat,
    required double lng,
    required ReportType type,
    String? description,
    String? city,
    String? neighborhood,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw const ReportException('Sem identificação. Tente de novo.');
    }
    final desc = description?.trim();
    final now = DateTime.now();
    final ref = await _db.collection('reports').add({
      'lat': lat,
      'lng': lng,
      'type': type.id,
      'description': desc == null || desc.isEmpty ? null : desc,
      'city': city,
      'neighborhood': neighborhood,
      'createdBy': uid,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(now.add(kReportTtl)),
      'status': 'pending',
      'confirmCount': 0,
      'contestCount': 0,
    });
    return ref.id;
  }

  /// Registra (ou troca) o voto do usuário num relato. Id do doc = uid,
  /// garante 1 voto por pessoa; revotar sobrescreve. O agregador server-side
  /// recalcula as contagens e decide confirmar/rejeitar.
  Future<void> vote({
    required String reportId,
    required ReportVote vote,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw const ReportException('Sem identificação. Tente de novo.');
    }
    await _db
        .collection('reports')
        .doc(reportId)
        .collection('votes')
        .doc(uid)
        .set({
      'vote': vote.id,
      'votedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Stream de um relato específico — pra o detalhe refletir contagens e
  /// status ao vivo depois de um voto.
  Stream<UserReport?> watchById(String reportId) {
    return _db.collection('reports').doc(reportId).snapshots().map(
          (doc) => doc.exists ? UserReport.fromFirestore(doc) : null,
        );
  }

  /// Stream do voto atual do usuário neste relato (ou null se não votou).
  Stream<ReportVote?> watchMyVote(String reportId) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(null);
    return _db
        .collection('reports')
        .doc(reportId)
        .collection('votes')
        .doc(uid)
        .snapshots()
        .map((d) {
      if (!d.exists) return null;
      final v = d.data()?['vote'] as String?;
      return v == 'confirm'
          ? ReportVote.confirm
          : v == 'contest'
              ? ReportVote.contest
              : null;
    });
  }

  /// uid corrente — pra a UI esconder o voto no próprio relato.
  String? get currentUid => _auth.currentUser?.uid;

  /// Stream dos relatos pendentes. Filtro de equality simples (sem índice
  /// composto); a expiração é refinada no cliente porque o scheduler pode
  /// ainda não ter passado.
  Stream<List<UserReport>> activePending() {
    return _db
        .collection('reports')
        .where('status', isEqualTo: 'pending')
        .limit(200)
        .snapshots()
        .map((snap) {
      final now = DateTime.now();
      return snap.docs
          .map(UserReport.fromFirestore)
          .where((r) => r.expiresAt == null || r.expiresAt!.isAfter(now))
          .toList();
    });
  }
}

class ReportException implements Exception {
  final String message;
  const ReportException(this.message);
  @override
  String toString() => message;
}

final reportServiceProvider = Provider<ReportService>(
  (ref) => ReportService(FirebaseFirestore.instance, FirebaseAuth.instance),
);

final activeReportsProvider = StreamProvider<List<UserReport>>(
  (ref) => ref.watch(reportServiceProvider).activePending(),
);

/// Relato específico ao vivo (detalhe).
final reportByIdProvider = StreamProvider.family<UserReport?, String>(
  (ref, reportId) => ref.watch(reportServiceProvider).watchById(reportId),
);

/// Voto atual do usuário num relato.
final myReportVoteProvider = StreamProvider.family<ReportVote?, String>(
  (ref, reportId) => ref.watch(reportServiceProvider).watchMyVote(reportId),
);
