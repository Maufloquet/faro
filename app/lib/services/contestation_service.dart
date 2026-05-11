import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ContestationReason {
  imprecise('Localização imprecisa'),
  notHappened('Evento não aconteceu'),
  alreadyResolved('Situação já resolvida'),
  exaggerated('Cobertura exagerada da fonte'),
  other('Outro motivo');

  final String label;
  const ContestationReason(this.label);
}

class ContestationService {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  ContestationService(this._db, this._auth);

  /// Grava uma contestação no Firestore.
  /// O detalhe é opcional. UID anônimo do usuário é gravado pra rastrear
  /// abuso (mesmo dispositivo contestando 100 relatos seguidos = sinal).
  Future<void> submit({
    required String occurrenceId,
    required ContestationReason reason,
    String? detail,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw const ContestationException('Sem identificação. Tente novamente.');
    }

    await _db.collection('contestations').add({
      'occurrenceId': occurrenceId,
      'reason': reason.name,
      'reasonLabel': reason.label,
      'detail': detail?.trim().isEmpty ?? true ? null : detail!.trim(),
      'submittedBy': uid,
      'submittedAt': FieldValue.serverTimestamp(),
      'status': 'pending',
    });
  }
}

class ContestationException implements Exception {
  final String message;
  const ContestationException(this.message);
  @override
  String toString() => message;
}

final contestationServiceProvider = Provider<ContestationService>(
  (ref) => ContestationService(FirebaseFirestore.instance, FirebaseAuth.instance),
);
