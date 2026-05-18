library;

import '../../models/occurrence.dart';
import '../i18n/faro_strings.dart';

/// Distribuição por hora do dia (0-23). Sempre 24 buckets — buckets vazios
/// retornam 0. Base pra mini-gráfico "quando concentra" e pra dashboard B2B.
///
/// Editorialmente: distribuição temporal nunca vira recomendação ("evite
/// 22h"). É contexto pra usuário escolher horário se tiver flexibilidade —
/// quem trabalha à noite não pode trocar.
class HourBucket {
  final int hour; // 0-23
  final int count;
  const HourBucket(this.hour, this.count);
}

/// Distribuição por dia da semana (1-7, segunda=1, domingo=7 — padrão Dart).
class WeekdayBucket {
  final int weekday; // DateTime.weekday (1=seg, 7=dom)
  final int count;
  const WeekdayBucket(this.weekday, this.count);
}

String labelForWeekday(int weekday) => FaroStrings.weekdayShort(weekday);

/// Conta ocorrências por hora local do relato. Resultado sempre tem 24
/// buckets ordenados de 0 a 23 (mesmo que zero).
List<HourBucket> rankByHour(List<Occurrence> occurrences) {
  final counts = List<int>.filled(24, 0);
  for (final o in occurrences) {
    final h = o.date.toLocal().hour;
    if (h >= 0 && h < 24) counts[h]++;
  }
  return [for (var h = 0; h < 24; h++) HourBucket(h, counts[h])];
}

/// Conta ocorrências por dia da semana. Resultado sempre tem 7 buckets
/// ordenados de segunda (1) a domingo (7).
List<WeekdayBucket> rankByWeekday(List<Occurrence> occurrences) {
  final counts = List<int>.filled(7, 0);
  for (final o in occurrences) {
    final w = o.date.toLocal().weekday; // 1-7
    if (w >= 1 && w <= 7) counts[w - 1]++;
  }
  return [for (var w = 1; w <= 7; w++) WeekdayBucket(w, counts[w - 1])];
}

/// Hora "pico" — bucket com maior contagem. Retorna null se nenhum bucket
/// tem dado (lista vazia ou totalmente zerada).
int? peakHour(List<HourBucket> buckets) {
  HourBucket? best;
  for (final b in buckets) {
    if (b.count == 0) continue;
    if (best == null || b.count > best.count) best = b;
  }
  return best?.hour;
}
