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
