import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/design/tokens.dart';
import '../core/design/typography.dart';
import '../core/i18n/faro_strings.dart';
import '../services/auth_service.dart';

/// Card de conta exibido em /Sobre/. Estados:
///
/// - **Anônimo (default)**: card explica que app funciona sem login;
///   botão "Entrar com Google" como opção, marketing zero.
/// - **Logado**: avatar + nome/email + botão "Sair".
///
/// Princípio mantido: anonymous é o ponto de partida; login é opt-in
/// explícito do usuário, sem pressão.
class AccountCard extends ConsumerStatefulWidget {
  const AccountCard({super.key});

  @override
  ConsumerState<AccountCard> createState() => _AccountCardState();
}

class _AccountCardState extends ConsumerState<AccountCard> {
  bool _busy = false;

  Future<void> _signIn() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(authServiceProvider).signInWithGoogle();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(FaroStrings.accountSignInFailed)),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOut() async {
    if (_busy) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(FaroStrings.accountSignOutConfirmTitle),
        content: Text(FaroStrings.accountSignOutConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(FaroStrings.accountSignOutCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: FaroColors.destructive,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(FaroStrings.accountSignOutConfirm),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await ref.read(authServiceProvider).signOut();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authStateProvider);
    final user = auth.maybeWhen(data: (u) => u, orElse: () => null);
    final isAnon = user == null || user.isAnonymous;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: FaroColors.sandSoft,
        borderRadius: BorderRadius.circular(FaroRadii.card),
        border: Border.all(color: FaroColors.sandBorder),
      ),
      child: isAnon ? _anonymousState() : _signedInState(user),
    );
  }

  Widget _anonymousState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.person_outline,
                size: 20, color: FaroColors.editorialBrown),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                FaroStrings.accountAnonymousTitle,
                style: FaroTextStyles.title(
                  fontSize: 15,
                  color: FaroColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          FaroStrings.accountAnonymousBody,
          style: FaroTextStyles.body(
            fontSize: 12.5,
            color: FaroColors.textSecondary,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _busy ? null : _signIn,
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.login, size: 18),
            label: Text(FaroStrings.accountSignInWithGoogle),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              side: const BorderSide(color: FaroColors.primary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _signedInState(User user) {
    final photoUrl = user.photoURL;
    final displayName = user.displayName;
    final email = user.email;
    return Row(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: FaroColors.primary.withValues(alpha: 0.1),
          backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
          child: photoUrl == null
              ? const Icon(Icons.person, color: FaroColors.primary)
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                FaroStrings.accountSignedInAs,
                style: FaroTextStyles.label(
                  fontSize: 11,
                  color: FaroColors.textSoft,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                displayName ?? email ?? '—',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: FaroTextStyles.title(
                  fontSize: 15,
                  color: FaroColors.textPrimary,
                ),
              ),
              if (email != null && email != displayName)
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: FaroTextStyles.body(
                    fontSize: 12,
                    color: FaroColors.textSoft,
                  ),
                ),
            ],
          ),
        ),
        TextButton(
          onPressed: _busy ? null : _signOut,
          style: TextButton.styleFrom(
            foregroundColor: FaroColors.destructive,
          ),
          child: Text(FaroStrings.accountSignOut),
        ),
      ],
    );
  }
}
