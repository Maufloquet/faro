library;

enum TimeWindow {
  hoje(Duration(hours: 24), 'Hoje'),
  semana(Duration(days: 7), '7 dias'),
  mes(Duration(days: 30), '30 dias'),
  tudo(null, 'Tudo');

  final Duration? duration;
  final String label;
  const TimeWindow(this.duration, this.label);

  bool includes(DateTime date) {
    final d = duration;
    if (d == null) return true;
    return DateTime.now().difference(date) <= d;
  }
}
