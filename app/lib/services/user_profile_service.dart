import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/log/faro_logger.dart';
import '../models/user_profile.dart';

/// CRUD do perfil do usuário em `/users/{uid}`.
///
/// O doc é o mesmo que já guarda referenceLocation e favoritos (em
/// subcoleção) — vamos só adicionar campos no topo. As Firestore rules
/// já garantem que cada usuário lê/escreve só o próprio.
class UserProfileService {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  static const _log = FaroLogger('user-profile');

  UserProfileService({FirebaseFirestore? db, FirebaseAuth? auth})
      : _db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  /// Stream do perfil do usuário atual. Reemite quando o doc muda
  /// (ex: outro device atualizou após login Google).
  ///
  /// Emite `UserProfile()` vazio enquanto o doc não existe — UI usa
  /// `isEmpty` pra mostrar estado "perfil ainda não preenchido".
  Stream<UserProfile> watch() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value(const UserProfile());
    }
    return _db
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .map((snap) {
      if (!snap.exists) return const UserProfile();
      return UserProfile.fromDoc(snap);
    });
  }

  /// Persiste alterações. Faz merge — só os campos passados são
  /// gravados, o resto (favoritos em subcoleção, referenceLocation)
  /// fica intacto.
  Future<void> save(UserProfile profile) async {
    final user = _auth.currentUser;
    if (user == null) {
      _log.warn('save() sem usuário corrente — ignorando');
      return;
    }
    try {
      await _db.collection('users').doc(user.uid).set(
        {
          ...profile.toMap(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e, s) {
      _log.error('save perfil falhou', e, s);
      rethrow;
    }
  }

  /// Apaga só os campos do perfil — preserva favoritos/referenceLocation.
  /// Usado pelo "Resetar perfil" e como parte do delete-account (LGPD).
  Future<void> clearProfileFields() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      await _db.collection('users').doc(user.uid).update({
        'displayName': FieldValue.delete(),
        'transportModes': FieldValue.delete(),
        'typicalHours': FieldValue.delete(),
        'mainNeighborhood': FieldValue.delete(),
        'mainCity': FieldValue.delete(),
        'notifications': FieldValue.delete(),
      });
    } catch (e, s) {
      _log.error('clear perfil falhou', e, s);
    }
  }
}

final userProfileServiceProvider = Provider<UserProfileService>(
  (_) => UserProfileService(),
);

final userProfileProvider = StreamProvider<UserProfile>((ref) {
  return ref.watch(userProfileServiceProvider).watch();
});
