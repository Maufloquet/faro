import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/design/tokens.dart';
import '../services/account_actions_service.dart';
import '../services/analytics_service.dart';
import 'legal_screen.dart';

/// Privacidade e dados: tela única que reúne Termos, Privacidade,
/// Exportar dados e Apagar conta. Atende aos direitos da LGPD em um
/// lugar fácil de achar.
class AccountActionsScreen extends ConsumerStatefulWidget {
  const AccountActionsScreen({super.key});

  @override
  ConsumerState<AccountActionsScreen> createState() =>
      _AccountActionsScreenState();
}

class _AccountActionsScreenState extends ConsumerState<AccountActionsScreen> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.logScreen('account_actions');
  }

  Future<void> _viewTerms({int tab = 0}) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => LegalScreen(initialTab: tab)),
    );
  }

  Future<void> _exportData() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final json = await ref.read(accountActionsServiceProvider).exportAsJson();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: const Text('Seus dados',
                style: TextStyle(fontFamily: 'Fraunces')),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 400, maxWidth: 500),
              child: SingleChildScrollView(
                child: SelectableText(
                  json,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11.5,
                    height: 1.4,
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Fechar'),
              ),
              FilledButton(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: json));
                  if (ctx.mounted) {
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Copiado pra área de transferência')),
                    );
                  }
                },
                child: const Text('Copiar'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível exportar: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteAccount() async {
    if (_busy) return;
    // Double-confirm — ação irreversível.
    final firstOk = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Apagar minha conta'),
        content: const Text(
          'Isso vai apagar todos os seus dados do Faro: perfil, favoritos, '
          'sua sessão. Não dá pra desfazer.\n\n'
          'Você tem certeza?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: FaroColors.destructive,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sim, apagar'),
          ),
        ],
      ),
    );
    if (firstOk != true) return;
    if (!mounted) return;

    final secondOk = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirma de novo'),
        content: const Text(
          'Última chance. Após apagar, você precisará reinstalar o app pra '
          'começar de novo. Continua?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Não, cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: FaroColors.destructive,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Apagar tudo'),
          ),
        ],
      ),
    );
    if (secondOk != true) return;

    setState(() => _busy = true);
    try {
      await ref.read(accountActionsServiceProvider).deleteAccount();
      if (!mounted) return;
      // App vai pra splash naturalmente no próximo authStateChanges, mas
      // pra UX imediata limpamos a pilha pra raiz.
      Navigator.of(context).popUntil((r) => r.isFirst);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Conta apagada.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().contains('requires-recent-login')
                ? 'Por segurança, faça login com Google de novo e tente apagar.'
                : 'Erro ao apagar: $e',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacidade e dados',
            style: TextStyle(fontFamily: 'Fraunces')),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          _ActionTile(
            icon: Icons.description_outlined,
            title: 'Termos de uso',
            subtitle: 'Como você se compromete ao usar o Faro',
            onTap: () => _viewTerms(),
          ),
          const SizedBox(height: 10),
          _ActionTile(
            icon: Icons.lock_outline,
            title: 'Política de privacidade',
            subtitle: 'Que dados o Faro coleta e o que faz com eles',
            onTap: () => _viewTerms(tab: 1),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Text(
              'Seus direitos sob a LGPD',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontFamily: 'Fraunces',
                    color: FaroColors.textSoft,
                  ),
            ),
          ),
          _ActionTile(
            icon: Icons.file_download_outlined,
            title: 'Exportar meus dados',
            subtitle: 'Vê tudo o que o Faro tem sobre você',
            onTap: _busy ? null : _exportData,
          ),
          const SizedBox(height: 10),
          _ActionTile(
            icon: Icons.delete_forever_outlined,
            title: 'Apagar minha conta',
            subtitle: 'Remove todos os seus dados. Irreversível.',
            destructive: true,
            onTap: _busy ? null : _deleteAccount,
          ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool destructive;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = destructive
        ? FaroColors.destructive
        : theme.colorScheme.onSurface;
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Row(
            children: [
              Icon(icon, size: 22, color: color),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontFamily: 'Fraunces',
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: FaroColors.textSoft,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: FaroColors.textHint),
            ],
          ),
        ),
      ),
    );
  }
}
