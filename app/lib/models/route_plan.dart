/// Plano de rota: origem → destino com raio de corredor.
///
/// Usado pra responder "vou da Pituba ao Centro às 22h, como tá o
/// caminho?" — o cliente avalia relatos recentes que caem dentro do
/// corredor (default 500m) entre os dois pontos.
///
/// MVP: linha reta. Não usamos API de routing real (Google Directions
/// cobra) — pra trajetos urbanos de até ~20km, o corredor reto cobre
/// a vizinhança das rotas óbvias com folga aceitável.
class RoutePlan {
  final double originLat;
  final double originLng;
  final String? originLabel;
  final double destinationLat;
  final double destinationLng;
  final String? destinationLabel;
  final double corridorKm;
  final Duration window;

  const RoutePlan({
    required this.originLat,
    required this.originLng,
    this.originLabel,
    required this.destinationLat,
    required this.destinationLng,
    this.destinationLabel,
    this.corridorKm = 0.5,
    this.window = const Duration(hours: 6),
  });
}
