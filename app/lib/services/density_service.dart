import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

/// Camada 7 — Densidade populacional por bairro.
///
/// Objetivo editorial: evitar que o app vire ranking de população. "Centro
/// tem mais relato porque tem mais gente" é viés. Normalizar relatos por
/// 10k habitantes mostra **intensidade** e não **volume bruto**.
///
/// Fontes:
/// - PDDU Salvador (Censo IBGE 2010), distribuído por Prefeitura-Bairro.
///   Estimativa por divisão simples entre bairros da PB.
/// - Bahia Notícias (Censo IBGE 2022) para bairros com dado publicado
///   diretamente — sobrescreve a estimativa.
/// - IBGE Cidades (Censo 2022) para populações municipais da RMS —
///   acessadas via `populationForCity` quando o bairro é desconhecido.
///
/// Bairros sem dado retornam null — UI deve esconder a normalização nesse
/// caso (preferimos silêncio honesto a número inventado).
class DensityService {
  DensityService._();
  static final DensityService instance = DensityService._();

  Map<String, _Entry>? _byBairro;
  Map<String, _Entry>? _byCity;

  Future<void> initialize() async {
    if (_byBairro != null) return;
    final raw = await rootBundle.loadString('assets/bairros_pop_salvador.json');
    final parsed = json.decode(raw) as Map<String, dynamic>;
    final bairros = <String, _Entry>{};
    final cities = <String, _Entry>{};
    parsed.forEach((key, value) {
      if (key == '_cities' && value is Map<String, dynamic>) {
        value.forEach((cityKey, cityValue) {
          final entry = _parse(cityValue);
          if (entry != null) cities[_normalize(cityKey)] = entry;
        });
        return;
      }
      if (key.startsWith('_')) return; // _meta e afins
      final entry = _parse(value);
      if (entry != null) {
        bairros[_normalize(key)] = entry;
      }
    });
    _byBairro = bairros;
    _byCity = cities;
  }

  /// População do bairro. Null se não temos o dado.
  int? populationFor(String? bairro) {
    if (bairro == null || bairro.isEmpty) return null;
    return _byBairro?[_normalize(bairro)]?.population;
  }

  /// Indica se o dado é estimativa (true) ou valor verificado (false).
  /// Retorna null quando não há dado pro bairro.
  bool? isEstimated(String? bairro) {
    if (bairro == null || bairro.isEmpty) return null;
    final entry = _byBairro?[_normalize(bairro)];
    if (entry == null) return null;
    return entry.confidence == 'estimated';
  }

  /// Relatos por 10k habitantes. Null se bairro desconhecido ou pop=0.
  ///
  /// Arredonda para 1 casa decimal pra evitar falsa precisão.
  double? per10kInhabitants({
    required String? bairro,
    required int count,
  }) {
    final pop = populationFor(bairro);
    if (pop == null || pop <= 0) return null;
    final value = (count * 10000) / pop;
    return double.parse(value.toStringAsFixed(1));
  }

  /// População do município. Útil pra contexto editorial quando o relato
  /// caiu no centroide da cidade (bairro desconhecido) e a UI quer
  /// ancorar o leitor.
  ///
  /// IMPORTANTE: não use isso pra calcular per10k de um bairro — usar
  /// pop municipal como denominador de um bairro específico é matemática
  /// errada. Pra isso temos `populationFor` (bairro) ou nada.
  int? populationForCity(String? city) {
    if (city == null || city.isEmpty) return null;
    return _byCity?[_normalize(city)]?.population;
  }

  /// Versão para teste — injeta populações direto sem carregar asset.
  /// Todos os valores injetados são marcados como `verified`.
  static DensityService testWith(
    Map<String, int> populations, {
    Map<String, int> cities = const {},
  }) {
    final s = DensityService._();
    s._byBairro = {
      for (final e in populations.entries)
        _normalize(e.key): _Entry(
          population: e.value,
          confidence: 'verified',
        ),
    };
    s._byCity = {
      for (final e in cities.entries)
        _normalize(e.key): _Entry(
          population: e.value,
          confidence: 'verified',
        ),
    };
    return s;
  }

  static _Entry? _parse(dynamic value) {
    // Schema antigo: valor numérico direto (mantido pra backward compat)
    if (value is int) {
      return _Entry(population: value, confidence: 'verified');
    }
    if (value is num) {
      return _Entry(population: value.toInt(), confidence: 'verified');
    }
    // Schema novo: objeto {population, source, confidence}
    if (value is Map<String, dynamic>) {
      final pop = value['population'];
      if (pop is num) {
        return _Entry(
          population: pop.toInt(),
          confidence: (value['confidence'] as String?) ?? 'verified',
        );
      }
    }
    return null;
  }

  static String _normalize(String s) {
    return s
        .toLowerCase()
        .replaceAll(RegExp(r'[áàâã]'), 'a')
        .replaceAll(RegExp(r'[éèê]'), 'e')
        .replaceAll(RegExp(r'[íì]'), 'i')
        .replaceAll(RegExp(r'[óòôõ]'), 'o')
        .replaceAll(RegExp(r'[úù]'), 'u')
        .replaceAll(RegExp(r'[ç]'), 'c')
        .trim();
  }
}

class _Entry {
  _Entry({required this.population, required this.confidence});
  final int population;
  final String confidence;
}
