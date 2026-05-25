import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/log/faro_logger.dart';

/// Região onde as Cloud Functions vivem. Callable precisa bater certo —
/// se ficar no default (us-central1), a chamada cai em "not-found".
const _functionsRegion = 'southamerica-east1';

/// Ações LGPD: exportar todos os dados do usuário, ou apagar a conta.
///
/// Divisão de trabalho:
/// - Exportar: o cliente lê o que consegue de si mesmo (`/users/{uid}` +
///   subcoleção `/favorites`). Contestações ficam de fora porque as rules
///   bloqueiam leitura — quem precisar da categoria pede por contato.
/// - Apagar: delega pra Cloud Function `deleteAccountCascade`, que roda com
///   admin SDK e cobre o que o cliente não alcança — contestações (delete
///   bloqueado pela rule) e a própria conta no Firebase Auth (sem o entrave
///   de `requires-recent-login`). Depois o cliente só desloga.
class AccountActionsService {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;
  static const _log = FaroLogger('account-actions');

  AccountActionsService({
    FirebaseFirestore? db,
    FirebaseAuth? auth,
    FirebaseFunctions? functions,
  })  : _db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _functions = functions ??
            FirebaseFunctions.instanceFor(region: _functionsRegion);

  /// Devolve um JSON serializado com tudo o que o Faro guarda do usuário:
  ///   - perfil em /users/{uid}
  ///   - favoritos em /users/{uid}/favorites
  ///   - tokens de push em /users/{uid}/fcmTokens
  ///   - contestações de autoria dele em /contestations
  ///
  /// O pacote completo vem da Cloud Function `exportUserData` (admin SDK),
  /// que é a única forma de incluir as contestações — as rules bloqueiam a
  /// leitura delas pelo cliente. Se a chamada falhar (offline, função fora
  /// do ar), caímos pra um export local parcial: perfil + favoritos, com
  /// aviso explícito de que as contestações ficaram de fora.
  ///
  /// Não inclui em nenhum caso:
  ///   - identificadores opacos do Firebase que não são "seus dados"
  ///   - analytics anônimas (não vinculadas ao uid)
  Future<String> exportAsJson() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Sem usuário corrente — não há dados a exportar.');
    }

    try {
      final callable = _functions.httpsCallable('exportUserData');
      final res = await callable.call<Map<String, dynamic>>();
      return const JsonEncoder.withIndent('  ').convert(res.data);
    } catch (e, s) {
      _log.error('export: callable falhou, caindo pro export local', e, s);
      return _exportLocalFallback(user);
    }
  }

  /// Export degradado, usado só quando a Cloud Function não responde. Lê o
  /// que o cliente alcança sozinho (perfil + favoritos) e declara a ausência
  /// das contestações em vez de fingir que o pacote está completo.
  Future<String> _exportLocalFallback(User user) async {
    final out = <String, dynamic>{
      'exportadoEm': DateTime.now().toIso8601String(),
      'parcial': true,
      'uid': user.uid,
      'email': user.email,
      'displayName': user.displayName,
      'anonimo': user.isAnonymous,
    };

    try {
      final userDoc = await _db.collection('users').doc(user.uid).get();
      out['perfil'] = userDoc.data() ?? <String, dynamic>{};
    } catch (e, s) {
      _log.error('export: ler perfil falhou', e, s);
      out['perfil'] = {'erro': e.toString()};
    }

    try {
      final favSnap =
          await _db.collection('users').doc(user.uid).collection('favorites').get();
      out['favoritos'] = favSnap.docs
          .map((d) => {'id': d.id, ...d.data()})
          .toList();
    } catch (e, s) {
      _log.error('export: ler favoritos falhou', e, s);
      out['favoritos'] = {'erro': e.toString()};
    }

    out['contestacoes'] = {
      'aviso':
          'Export parcial: a função de exportação completa não respondeu. '
              'Contestações ficam de fora porque o app não pode lê-las direto. '
              'Tente de novo com conexão, ou peça via contato@faro.app.',
    };

    return const JsonEncoder.withIndent('  ').convert(out);
  }

  /// Apaga conta + dados associados. Operação irreversível.
  ///
  /// Tudo acontece server-side na Cloud Function `deleteAccountCascade`,
  /// numa ordem única: contestações → doc /users/{uid} e subcoleções
  /// (favorites, fcmTokens) → conta no Firebase Auth. Concentrar no admin
  /// SDK resolve dois entraves do cliente: a rule que proíbe apagar
  /// contestações e o `requires-recent-login` do `user.delete()`.
  ///
  /// Depois que a function retorna, a conta Auth já não existe — o cliente
  /// só limpa o estado local com signOut. Se a function falhar, propagamos
  /// o erro e nada foi apagado pela metade (ela aborta antes de tocar no
  /// Auth se a deleção de dados falhar).
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Sem usuário corrente.');
    }

    try {
      final callable = _functions.httpsCallable('deleteAccountCascade');
      await callable.call<Map<String, dynamic>>();
    } on FirebaseFunctionsException catch (e, s) {
      _log.error('delete: cascade falhou (${e.code})', e, s);
      rethrow;
    } catch (e, s) {
      _log.error('delete: cascade falhou', e, s);
      rethrow;
    }

    // A conta já foi apagada no servidor; aqui só derrubamos a sessão local
    // pra o app voltar ao estado deslogado. Falha aqui não desfaz a deleção.
    try {
      await _auth.signOut();
    } catch (e, s) {
      _log.error('delete: signOut local falhou (conta já apagada)', e, s);
    }
  }
}

final accountActionsServiceProvider = Provider<AccountActionsService>(
  (_) => AccountActionsService(),
);
