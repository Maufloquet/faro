import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/i18n/faro_strings.dart';

enum ContestationReason {
  imprecise,
  notHappened,
  alreadyResolved,
  exaggerated,
  other;

  String get label {
    switch (this) {
      case ContestationReason.imprecise:
        return FaroStrings.contestReasonImprecise;
      case ContestationReason.notHappened:
        return FaroStrings.contestReasonNotHappened;
      case ContestationReason.alreadyResolved:
        return FaroStrings.contestReasonAlreadyResolved;
      case ContestationReason.exaggerated:
        return FaroStrings.contestReasonExaggerated;
      case ContestationReason.other:
        return FaroStrings.contestReasonOther;
    }
  }
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
