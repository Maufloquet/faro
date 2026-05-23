import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/geo/corridor.dart';
import '../models/occurrence.dart';
import '../models/route_plan.dart';
import 'occurrences_service.dart';

/// Avalia relatos no corredor da rota. Filtra in-memory a partir do
/// stream de occurrences recentes que o app já mantém — evita query
/// específica no Firestore (cobre apenas BA hoje, dataset enxuto).
class RouteEvaluation {
  final List<Occurrence> inCorridor;
  final RoutePlan plan;

  const RouteEvaluation({required this.inCorridor, required this.plan});

  int get count => inCorridor.length;
  bool get isEmpty => inCorridor.isEmpty;

  /// Texto editorial neutro pra exibir no cabeçalho da rota. Sem
  /// palavras alarmistas — princípio do Faro.
  String headline() {
    if (isEmpty) {
      return 'Trajeto sem relatos nas últimas ${plan.window.inHours}h.';
    }
    final corridor = (plan.corridorKm * 1000).toInt();
    return count == 1
        ? '1 relato no corredor de ${corridor}m nas últimas ${plan.window.inHours}h.'
        : '$count relatos no corredor de ${corridor}m nas últimas ${plan.window.inHours}h.';
  }
}

class RoutePlanService {
  /// Filtra a lista de ocorrências mantendo só as que caem no corredor
  /// e dentro da janela temporal. Função pura — testável sem Firestore.
  RouteEvaluation evaluate(
    RoutePlan plan,
    List<Occurrence> occurrences, {
    DateTime? now,
  }) {
    final ts = now ?? DateTime.now();
    final cutoff = ts.subtract(plan.window);
    final kept = <Occurrence>[];
    for (final o in occurrences) {
      if (o.date.isBefore(cutoff)) continue;
      final inCorridor = pointInCorridor(
        pointLat: o.latitude,
        pointLng: o.longitude,
        aLat: plan.originLat,
        aLng: plan.originLng,
        bLat: plan.destinationLat,
        bLng: plan.destinationLng,
        bufferKm: plan.corridorKm,
      );
      if (!inCorridor) continue;
      kept.add(o);
    }
    // Ordena por data desc — relato mais recente primeiro.
    kept.sort((a, b) => b.date.compareTo(a.date));
    return RouteEvaluation(inCorridor: kept, plan: plan);
  }
}

final routePlanServiceProvider = Provider<RoutePlanService>(
  (_) => RoutePlanService(),
);

/// Avalia um RoutePlan combinado com o stream atual de occurrences.
/// Retorna RouteEvaluation com a lista filtrada.
final routeEvaluationProvider =
    Provider.family<AsyncValue<RouteEvaluation>, RoutePlan>((ref, plan) {
  final async = ref.watch(recentOccurrencesProvider);
  return async.whenData((list) =>
      ref.watch(routePlanServiceProvider).evaluate(plan, list));
});
