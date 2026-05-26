import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/design/tokens.dart';
import '../models/watched_route.dart';
import '../services/analytics_service.dart';
import '../services/watched_route_service.dart';

/// Lista os trajetos que o usuário pediu pra observar e permite removê-los.
/// Os alertas chegam por push quando aparece relato novo no corredor.
class WatchedRoutesScreen extends ConsumerStatefulWidget {
  const WatchedRoutesScreen({super.key});

  @override
  ConsumerState<WatchedRoutesScreen> createState() =>
      _WatchedRoutesScreenState();
}

class _WatchedRoutesScreenState extends ConsumerState<WatchedRoutesScreen> {
  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.logScreen('watched_routes');
  }

  Future<void> _remove(WatchedRoute r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Parar de observar'),
        content: Text('Deixar de receber avisos sobre "${r.label}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Parar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(watchedRouteServiceProvider).remove(r.id);
  }

  @override
  Widget build(BuildContext context) {
    final routes = ref.watch(watchedRoutesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trajetos observados',
            style: TextStyle(fontFamily: 'Fraunces')),
        elevation: 0,
      ),
      body: routes.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Não foi possível carregar: $e')),
        data: (list) {
          if (list.isEmpty) return const _Empty();
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: list.length,
            separatorBuilder: (_, _) =>
                const Divider(height: 1, indent: 16, endIndent: 16),
            itemBuilder: (_, i) {
              final r = list[i];
              return ListTile(
                leading: const Icon(Icons.route_outlined,
                    color: FaroColors.primary),
                title: Text(r.label),
                subtitle: Text(
                  'Corredor de ${r.corridorMeters.toInt()}m · avisamos por push',
                  style: const TextStyle(fontSize: 12.5),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: FaroColors.textMuted),
                  tooltip: 'Parar de observar',
                  onPressed: () => _remove(r),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.route_outlined, size: 40, color: FaroColors.textHint),
          SizedBox(height: 14),
          Text(
            'Nenhum trajeto observado ainda.',
            style: TextStyle(
              fontFamily: 'Fraunces',
              fontSize: 16,
              color: FaroColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 6),
          Text(
            'Avalie um trajeto e toque em "Observar" pra ser avisado quando '
            'aparecer relato novo no caminho.',
            style: TextStyle(fontSize: 13, height: 1.5, color: FaroColors.textMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
