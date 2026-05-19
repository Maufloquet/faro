import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../core/log/faro_logger.dart';

/// Camada de autenticação do Faro.
///
/// Princípio mantido: anonymous é o **default** — o app abre e funciona
/// sem login. Login Google é **opcional**, oferecido em /Sobre/ pra
/// quem quiser sync cross-device, favoritos persistidos, etc.
///
/// Estratégia de upgrade: quando o usuário anônimo loga com Google,
/// fazemos `linkWithCredential` — o UID anônimo vira a conta Google,
/// preservando dados já gravados (contestações, etc). Se a conta Google
/// já existia no Firebase (em outro device), caímos pra `signInWithCredential`
/// e descartamos o UID anônimo local — é o trade-off pra ter mesma conta.
class AuthService {
  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;
  static const _log = FaroLogger('auth');

  AuthService({FirebaseAuth? auth, GoogleSignIn? googleSignIn})
      : _auth = auth ?? FirebaseAuth.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn();

  /// Stream de mudanças no usuário (login/logout/criação anônima).
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  /// `true` se o usuário ainda é anônimo (default), `false` se logou com Google.
  bool get isAnonymous => _auth.currentUser?.isAnonymous ?? true;

  String? get email => _auth.currentUser?.email;
  String? get displayName => _auth.currentUser?.displayName;
  String? get photoUrl => _auth.currentUser?.photoURL;

  /// Login com Google. Tenta linkar com o usuário anônimo atual
  /// (preserva o UID). Se a conta Google já tem registro Firebase,
  /// faz sign-in puro (UID anônimo local é descartado pelo SDK).
  ///
  /// Retorna o [User] resultante, ou `null` se o usuário cancelou o
  /// fluxo (não selecionou conta no diálogo do Google).
  Future<User?> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null;
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final current = _auth.currentUser;
    if (current != null && current.isAnonymous) {
      try {
        final result = await current.linkWithCredential(credential);
        _log.info('upgrade anonymous → google: ${result.user?.uid}');
        return result.user;
      } on FirebaseAuthException catch (e) {
        if (e.code == 'credential-already-in-use' ||
            e.code == 'email-already-in-use') {
          // Conta Google já existia (login em outro device). Cai pra
          // sign-in normal — UID anônimo local fica abandonado.
          _log.info('conta google preexistia, fallback sign-in: ${e.code}');
          final result = await _auth.signInWithCredential(credential);
          return result.user;
        }
        rethrow;
      }
    }

    // Sem usuário corrente, ou já era não-anônimo: sign-in direto.
    final result = await _auth.signInWithCredential(credential);
    return result.user;
  }

  /// Sai da conta Google e recria sessão anônima pra app continuar
  /// funcionando (contestações etc precisam de algum UID).
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (e) {
      _log.error('google sign out falhou', e);
    }
    await _auth.signOut();
    try {
      await _auth.signInAnonymously();
    } catch (e, s) {
      _log.error('recriação anonymous falhou pós-logout', e, s);
    }
  }
}

final authServiceProvider = Provider<AuthService>((_) => AuthService());

/// Stream do usuário atual — observa login/logout pra a UI reagir.
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});
