/// Helpers de formatação textual usados em vários lugares.
library;

const _smallWords = {'da', 'de', 'do', 'das', 'dos', 'e'};

/// Converte "GOES CALMON" ou "são cristóvão" em "Góes Calmon" / "São Cristóvão".
///
/// Mantém preposições e conjunções em minúsculo, exceto se for a primeira
/// palavra. Não tenta restaurar acentos perdidos (fonte: dados públicos
/// brasileiros geralmente já vêm com acentos corretos OU sem nenhum).
String titleCasePtBr(String? raw) {
  if (raw == null || raw.isEmpty) return '';
  final words = raw.trim().toLowerCase().split(RegExp(r'\s+'));
  return words.asMap().entries.map((e) {
    final i = e.key;
    final w = e.value;
    if (w.isEmpty) return w;
    if (i > 0 && _smallWords.contains(w)) return w;
    return w[0].toUpperCase() + w.substring(1);
  }).join(' ');
}
