import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/log/faro_logger.dart';

/// Ações LGPD: exportar todos os dados do usuário, ou apagar a conta.
///
/// Por que o cliente faz isso direto (e não Cloud Function):
/// - Exportar: dados estão todos sob `/users/{uid}` + `/contestations`
///   onde `submittedBy == uid`. Tudo legível com auth do próprio usuário.
/// - Apagar: mesma lógica. Rules permitem o dono deletar o que escreveu
///   no `/users/{uid}` e subcoleção `/favorites`. Contestações não têm
///   delete pelo cliente (rule explícita) — então pra apagar de verdade
///   precisamos da Cloud Function (`deleteAccountCascade`), que rodará
///   com admin SDK e cobrirá tudo. Por ora documentamos como TODO.
class AccountActionsService {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  static const _log = FaroLogger('account-actions');

  AccountActionsService({FirebaseFirestore? db, FirebaseAuth? auth})
      : _db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  /// Devolve um JSON serializado com tudo o que o usuário pode ler
  /// dele mesmo. Inclui:
  ///   - perfil em /users/{uid}
  ///   - favoritos em /users/{uid}/favorites
  ///   - contestações de autoria dele em /contestations
  ///
  /// Não inclui:
  ///   - identificadores opacos do Firebase (não são "seus dados")
  ///   - analytics anônimas (não vinculadas ao uid)
  Future<String> exportAsJson() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Sem usuário corrente — não há dados a exportar.');
    }

    final out = <String, dynamic>{
      'exportadoEm': DateTime.now().toIso8601String(),
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

    // Contestações: rules bloqueiam READ pra qualquer cliente, então
    // mesmo o próprio autor não consegue listar. Pra LGPD strict
    // teríamos uma Cloud Function exportData() com admin SDK que
    // varre /contestations onde submittedBy == uid. Por ora,
    // declaramos a ausência explicitamente.
    out['contestacoes'] = {
      'aviso':
          'Contestações são gravadas mas o cliente não pode listá-las '
              '(política de moderação). Pedir exportação completa via '
              'contato@faro.app pra incluir essa categoria.',
    };

    return const JsonEncoder.withIndent('  ').convert(out);
  }

  /// Apaga conta + dados associados. Operação irreversível.
  ///
  /// Hoje cobre client-side:
  ///   1. Apaga subcoleção /users/{uid}/favorites
  ///   2. Apaga doc /users/{uid}
  ///   3. signOut + delete() do Firebase Auth
  ///
  /// Não cobre (pendente Cloud Function `deleteAccountCascade`):
  ///   - Contestações (sem delete client-side)
  ///   - Re-anonimização de docs já gravados que mencionam o uid em campos
  ///
  /// Em caso de erro no meio, o que conseguir apagar fica apagado — o
  /// resto pode ser limpo posteriormente via solicitação manual.
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Sem usuário corrente.');
    }
    final uid = user.uid;

    try {
      // Subcoleção: favoritos
      final favSnap =
          await _db.collection('users').doc(uid).collection('favorites').get();
      final batch = _db.batch();
      for (final doc in favSnap.docs) {
        batch.delete(doc.reference);
      }
      if (favSnap.docs.isNotEmpty) await batch.commit();
    } catch (e, s) {
      _log.error('delete: limpar favoritos falhou', e, s);
    }

    try {
      await _db.collection('users').doc(uid).delete();
    } catch (e, s) {
      _log.error('delete: apagar perfil falhou', e, s);
    }

    try {
      await user.delete();
    } catch (e, s) {
      _log.error('delete: apagar conta Auth falhou', e, s);
      // Se a conta Google exige re-autenticação recente (requires-recent-login),
      // o caller precisa pedir login antes de chamar de novo. Propagamos.
      rethrow;
    }
  }
}

final accountActionsServiceProvider = Provider<AccountActionsService>(
  (_) => AccountActionsService(),
);
