import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/admin_metrics.dart';
import '../models/job_health.dart';
import '../services/admin_metrics_service.dart';
import '../services/analytics_service.dart';

/// Painel admin interno. Acessível por deep link `faro://admin` (ver
/// configuração de URL scheme em AndroidManifest e Info.plist) e gateado
/// no Firestore por custom claim — o cliente comum vê erro de permissão
/// e o `AsyncError` rebate como "acesso negado" sem expor nada do schema.
///
/// O painel é deliberadamente sem badge/marketing — é ferramenta operacional,
/// não feature de produto.
class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen> {
  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.logScreen('admin');
    // Refresh forçado pra puxar custom claim recém-concedido sem esperar
    // o TTL de 1h do ID token. Resultado fica cacheado no provider.
    ref.read(isAdminProvider);
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(isAdminProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Painel', style: TextStyle(fontFamily: 'Fraunces')),
        elevation: 0,
      ),
      body: isAdmin.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _Denied(message: 'Sem permissão (${e.runtimeType}).'),
        data: (granted) {
          if (!granted) {
            return const _Denied(
              message: 'Esta conta não tem acesso ao painel.',
            );
          }
          return const _MetricsBody();
        },
      ),
    );
  }
}

class _Denied extends StatelessWidget {
  final String message;
  const _Denied({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}

class _MetricsBody extends ConsumerWidget {
  const _MetricsBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metrics = ref.watch(adminMetricsProvider);

    return metrics.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _Denied(
        message: 'Não foi possível carregar (${e.runtimeType}).',
      ),
      data: (m) => RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(adminMetricsProvider);
          await ref.read(adminMetricsProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            _SampledAtHeader(sampledAt: m.sampledAt),
            const SizedBox(height: 16),
            const _JobHealthCard(),
            const SizedBox(height: 12),
            _UsersCard(users: m.users),
            const SizedBox(height: 12),
            _OccurrencesCard(occurrences: m.occurrences),
            const SizedBox(height: 12),
            _ContestationsCard(contestations: m.contestations),
            const SizedBox(height: 12),
            _SafeArrivalsCard(safeArrivals: m.safeArrivals),
          ],
        ),
      ),
    );
  }
}

class _SampledAtHeader extends StatelessWidget {
  final DateTime? sampledAt;
  const _SampledAtHeader({required this.sampledAt});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = sampledAt;
    final label = s == null
        ? 'Coleta ainda não rodou'
        : 'Última coleta: ${_formatAgo(s)}';
    return Text(
      label,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }

  static String _formatAgo(DateTime sampledAt) {
    final delta = DateTime.now().difference(sampledAt);
    if (delta.inMinutes < 1) return 'agora há pouco';
    if (delta.inMinutes < 60) return '${delta.inMinutes} min atrás';
    if (delta.inHours < 24) return '${delta.inHours} h atrás';
    return '${delta.inDays} d atrás';
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _MetricCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontFamily: 'Fraunces',
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _KpiRow extends StatelessWidget {
  final String label;
  final String value;
  const _KpiRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _UsersCard extends StatelessWidget {
  final UserMetrics users;
  const _UsersCard({required this.users});

  @override
  Widget build(BuildContext context) {
    return _MetricCard(
      title: 'Usuários',
      child: Column(
        children: [
          _KpiRow(label: 'Total', value: '${users.total}'),
          _KpiRow(label: 'Anônimos', value: '${users.anonymous}'),
          _KpiRow(label: 'Logados com Google', value: '${users.google}'),
          const Divider(height: 24),
          _KpiRow(label: 'Novos nas últimas 24h', value: '${users.createdLast24h}'),
          _KpiRow(label: 'Novos nos últimos 7d', value: '${users.createdLast7d}'),
          _KpiRow(label: 'Ativos nas últimas 24h', value: '${users.activeLast24h}'),
          _KpiRow(label: 'Ativos nos últimos 7d', value: '${users.activeLast7d}'),
        ],
      ),
    );
  }
}

class _OccurrencesCard extends StatelessWidget {
  final OccurrenceMetrics occurrences;
  const _OccurrencesCard({required this.occurrences});

  @override
  Widget build(BuildContext context) {
    return _MetricCard(
      title: 'Ocorrências',
      child: Column(
        children: [
          _KpiRow(label: 'Total (all-time)', value: '${occurrences.total}'),
          _KpiRow(label: 'Últimas 24h', value: '${occurrences.last24h}'),
          _KpiRow(label: 'Últimos 7d', value: '${occurrences.last7d}'),
          _KpiRow(label: 'Contestadas (7d)', value: '${occurrences.contested}'),
          if (occurrences.bySource.isNotEmpty) ...[
            const Divider(height: 24),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Por fonte (7d)'),
            ),
            const SizedBox(height: 6),
            ..._sortedEntries(occurrences.bySource).map(
              (e) => _KpiRow(label: e.key, value: '${e.value}'),
            ),
          ],
          if (occurrences.byCity.isNotEmpty) ...[
            const Divider(height: 24),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Por cidade (7d)'),
            ),
            const SizedBox(height: 6),
            ..._sortedEntries(occurrences.byCity).take(8).map(
                  (e) => _KpiRow(label: e.key, value: '${e.value}'),
                ),
          ],
          if (occurrences.topReasons.isNotEmpty) ...[
            const Divider(height: 24),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Principais motivos (7d)'),
            ),
            const SizedBox(height: 6),
            ...occurrences.topReasons.map(
              (r) => _KpiRow(label: r.reason, value: '${r.count}'),
            ),
          ],
        ],
      ),
    );
  }

  List<MapEntry<String, int>> _sortedEntries(Map<String, int> m) {
    final entries = m.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries;
  }
}

class _ContestationsCard extends StatelessWidget {
  final ContestationMetrics contestations;
  const _ContestationsCard({required this.contestations});

  @override
  Widget build(BuildContext context) {
    return _MetricCard(
      title: 'Contestações',
      child: Column(
        children: [
          _KpiRow(label: 'Total registradas', value: '${contestations.total}'),
          _KpiRow(
            label: 'Ocorrências distintas contestadas',
            value: '${contestations.occurrencesContested}',
          ),
        ],
      ),
    );
  }
}

class _JobHealthCard extends ConsumerWidget {
  const _JobHealthCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncJobs = ref.watch(jobHealthProvider);
    return _MetricCard(
      title: 'Saúde dos schedulers',
      child: asyncJobs.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: LinearProgressIndicator(),
        ),
        error: (e, _) => Text(
          'Não foi possível carregar (${e.runtimeType}).',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        data: (jobs) {
          if (jobs.isEmpty) {
            return Text(
              'Nenhum heartbeat ainda — os schedulers escrevem aqui no fim de cada run.',
              style: Theme.of(context).textTheme.bodySmall,
            );
          }
          // Mostra todos os jobs conhecidos, mesmo os que ainda não emitiram
          // heartbeat — assim a ausência salta visualmente (vermelho).
          final byName = {for (final j in jobs) j.name: j};
          final allNames = {...kJobIntervals.keys, ...byName.keys}.toList()
            ..sort();
          return Column(
            children: [
              for (final name in allNames)
                _JobHealthRow(
                  name: name,
                  job: byName[name],
                  expected: kJobIntervals[name] ?? const Duration(hours: 1),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _JobHealthRow extends StatelessWidget {
  final String name;
  final JobHealth? job;
  final Duration expected;
  const _JobHealthRow({required this.name, required this.job, required this.expected});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final j = job;
    final level = j?.level(expectedInterval: expected) ?? JobHealthLevel.error;
    final color = switch (level) {
      JobHealthLevel.ok => Colors.green.shade700,
      JobHealthLevel.stale => Colors.amber.shade800,
      JobHealthLevel.error => theme.colorScheme.error,
    };
    final subtitle = _subtitleFor(j);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (j?.itemsWritten != null)
            Text(
              '${j!.itemsWritten} itens',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
        ],
      ),
    );
  }

  String _subtitleFor(JobHealth? j) {
    if (j == null) return 'sem heartbeat ainda';
    final ts = j.lastRunAt;
    if (ts == null) return 'sem timestamp';
    final age = _ago(ts);
    if (j.status == JobStatus.error) {
      final err = j.lastError;
      return err == null ? 'falhou há $age' : 'falhou há $age — $err';
    }
    return 'ok há $age';
  }

  String _ago(DateTime ts) {
    final delta = DateTime.now().difference(ts);
    if (delta.inMinutes < 1) return 'instantes';
    if (delta.inMinutes < 60) return '${delta.inMinutes} min';
    if (delta.inHours < 24) return '${delta.inHours} h';
    return '${delta.inDays} d';
  }
}

class _SafeArrivalsCard extends StatelessWidget {
  final SafeArrivalMetrics safeArrivals;
  const _SafeArrivalsCard({required this.safeArrivals});

  @override
  Widget build(BuildContext context) {
    return _MetricCard(
      title: 'Cheguei bem',
      child: Column(
        children: [
          _KpiRow(label: 'Últimas 24h', value: '${safeArrivals.last24h}'),
          _KpiRow(label: 'Últimos 7d', value: '${safeArrivals.last7d}'),
        ],
      ),
    );
  }
}
