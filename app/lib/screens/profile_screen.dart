import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/design/tokens.dart';
import '../models/user_profile.dart';
import '../services/analytics_service.dart';
import '../services/user_profile_service.dart';

/// Tela "Meu perfil" — gestão dos dados opcionais do usuário.
///
/// Princípio editorial: tudo opcional, tudo pulável. O app continua
/// funcionando com perfil vazio. Preencher só ajuda a personalizar
/// resumo diário, sugestões de rota e o widget da home.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.logScreen('profile');
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(userProfileProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meu perfil', style: TextStyle(fontFamily: 'Fraunces')),
        elevation: 0,
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(
              'Não foi possível carregar (${e.runtimeType}).',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ),
        data: (profile) => _Body(profile: profile),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  final UserProfile profile;
  const _Body({required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        if (profile.isEmpty) const _EmptyHero(),
        _NameCard(profile: profile),
        const SizedBox(height: 12),
        _TransportCard(profile: profile),
        const SizedBox(height: 12),
        _HoursCard(profile: profile),
        const SizedBox(height: 12),
        _NeighborhoodCard(profile: profile),
        const SizedBox(height: 24),
        Text(
          'Notificações',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontFamily: 'Fraunces',
                color: FaroColors.textSoft,
              ),
        ),
        const SizedBox(height: 8),
        _DigestToggle(profile: profile),
        const SizedBox(height: 24),
        Text(
          'Tudo opcional. O Faro funciona sem você preencher nada — esses '
          'campos só ajudam a personalizar resumo diário, sugestões de rota '
          'e o widget da home.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: FaroColors.textHint,
                fontStyle: FontStyle.italic,
              ),
        ),
      ],
    );
  }
}

class _DigestToggle extends ConsumerWidget {
  final UserProfile profile;
  const _DigestToggle({required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(
          'Resumo do dia (manhã)',
          style: theme.textTheme.titleSmall?.copyWith(
            fontFamily: 'Fraunces',
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          'Notificação às 7h com o que rolou no seu bairro nas últimas 24h.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: FaroColors.textSoft,
          ),
        ),
        value: profile.notifications.dailyDigest,
        onChanged: (v) async {
          final next = profile.copyWith(
            notifications: profile.notifications.copyWith(dailyDigest: v),
          );
          await ref.read(userProfileServiceProvider).save(next);
        },
      ),
    );
  }
}

class _EmptyHero extends StatelessWidget {
  const _EmptyHero();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Perfil vazio',
              style: theme.textTheme.titleSmall?.copyWith(
                fontFamily: 'Fraunces',
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Preencha o que quiser. Cada campo deixa o Faro mais útil pra você '
              'sem expor seu nome ou rotina pra ninguém.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: FaroColors.textSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardShell extends StatelessWidget {
  final String title;
  final String? summary;
  final VoidCallback onTap;
  const _CardShell({required this.title, required this.summary, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                            fontFamily: 'Fraunces',
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      summary ?? 'Não informado',
                      style: theme.textTheme.bodyMedium?.copyWith(
                            color: summary == null
                                ? FaroColors.textHint
                                : theme.colorScheme.onSurface,
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

class _NameCard extends ConsumerWidget {
  final UserProfile profile;
  const _NameCard({required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _CardShell(
      title: 'Como prefere ser chamado',
      summary: profile.displayName,
      onTap: () async {
        final value = await _showTextEditor(
          context,
          title: 'Como prefere ser chamado',
          initial: profile.displayName ?? '',
          hint: 'Opcional. Aparece em mensagens personalizadas do Faro.',
        );
        if (value != null) {
          final next = profile.copyWith(displayName: value.isEmpty ? null : value);
          await ref.read(userProfileServiceProvider).save(next);
        }
      },
    );
  }
}

class _TransportCard extends ConsumerWidget {
  final UserProfile profile;
  const _TransportCard({required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modes = profile.transportModes;
    final summary = modes.isEmpty ? null : modes.map((m) => m.label).join(', ');
    return _CardShell(
      title: 'Como você se locomove',
      summary: summary,
      onTap: () async {
        final next = await _showMultiSelect<TransportMode>(
          context,
          title: 'Como você se locomove',
          options: TransportMode.values,
          selected: modes.toSet(),
          labelOf: (m) => m.label,
          subtitle: 'Pode marcar mais de um. Usamos pra montar resumo do trajeto.',
        );
        if (next != null) {
          await ref
              .read(userProfileServiceProvider)
              .save(profile.copyWith(transportModes: next.toList()));
        }
      },
    );
  }
}

class _HoursCard extends ConsumerWidget {
  final UserProfile profile;
  const _HoursCard({required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hours = profile.typicalHours;
    final summary = hours.isEmpty ? null : hours.map((h) => h.label).join(' · ');
    return _CardShell(
      title: 'Horários que você costuma andar',
      summary: summary,
      onTap: () async {
        final next = await _showMultiSelect<HourBand>(
          context,
          title: 'Horários típicos',
          options: HourBand.values,
          selected: hours.toSet(),
          labelOf: (h) => h.label,
          subtitle:
              'Quanto mais marcar, mais relevantes os resumos. Tudo opcional.',
        );
        if (next != null) {
          await ref
              .read(userProfileServiceProvider)
              .save(profile.copyWith(typicalHours: next.toList()));
        }
      },
    );
  }
}

class _NeighborhoodCard extends ConsumerWidget {
  final UserProfile profile;
  const _NeighborhoodCard({required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = profile.mainNeighborhood == null
        ? null
        : '${profile.mainNeighborhood}'
            '${profile.mainCity != null ? ' · ${profile.mainCity}' : ''}';
    return _CardShell(
      title: 'Bairro principal',
      summary: summary,
      onTap: () async {
        final value = await _showTextEditor(
          context,
          title: 'Bairro principal',
          initial: profile.mainNeighborhood ?? '',
          hint:
              'Bairro onde você mora ou passa mais tempo. Resumo diário foca aqui.',
        );
        if (value != null) {
          final next = profile.copyWith(
            mainNeighborhood: value.isEmpty ? null : value,
          );
          await ref.read(userProfileServiceProvider).save(next);
        }
      },
    );
  }
}

Future<String?> _showTextEditor(
  BuildContext context, {
  required String title,
  required String initial,
  required String hint,
}) async {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: Text(title, style: const TextStyle(fontFamily: 'Fraunces')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(hint, style: Theme.of(ctx).textTheme.bodySmall),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Salvar'),
          ),
        ],
      );
    },
  );
}

Future<Set<T>?> _showMultiSelect<T>(
  BuildContext context, {
  required String title,
  required List<T> options,
  required Set<T> selected,
  required String Function(T) labelOf,
  required String subtitle,
}) async {
  final draft = {...selected};
  return showModalBottomSheet<Set<T>>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setState) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                          fontFamily: 'Fraunces',
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                            color: FaroColors.textSoft,
                          )),
                  const SizedBox(height: 12),
                  ...options.map(
                    (opt) => CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(labelOf(opt)),
                      value: draft.contains(opt),
                      onChanged: (v) => setState(() {
                        if (v == true) {
                          draft.add(opt);
                        } else {
                          draft.remove(opt);
                        }
                      }),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Cancelar'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () => Navigator.of(ctx).pop(draft),
                        child: const Text('Salvar'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
