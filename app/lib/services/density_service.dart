import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

/// Camada 7 — Densidade populacional por bairro.
///
/// Objetivo editorial: evitar que o app vire ranking de população. "Centro
/// tem mais relato porque tem mais gente" é viés. Normalizar relatos por
/// 10k habitantes mostra **intensidade** e não **volume bruto**.
///
/// Fonte atual: Censo IBGE 2010 via PMS/SEMOP (consolidado por bairro).
/// Censo 2022 ainda não publicou agregação bairro-granular para Salvador.
/// Bairros sem dado retornam null — UI deve esconder a normalização nesse
/// caso (preferimos silêncio honesto a número inventado).
class DensityService {
  DensityService._();
  static final DensityService instance = DensityService._();

  Map<String, int>? _populationByBairro;

  Future<void> initialize() async {
    if (_populationByBairro != null) return;
    final raw = await rootBundle.loadString('assets/bairros_pop_salvador.json');
    final parsed = json.decode(raw) as Map<String, dynamic>;
    final map = <String, int>{};
    parsed.forEach((key, value) {
      if (key.startsWith('_')) return; // _meta
      if (value is int) {
        map[_normalize(key)] = value;
      } else if (value is num) {
        map[_normalize(key)] = value.toInt();
      }
    });
    _populationByBairro = map;
  }

  /// População estimada do bairro. Null se não temos o dado.
  int? populationFor(String? bairro) {
    if (bairro == null || bairro.isEmpty) return null;
    final pop = _populationByBairro?[_normalize(bairro)];
    return pop;
  }

  /// Relatos por 10k habitantes. Null se bairro desconhecido ou pop=0.
  ///
  /// Arredonda para 1 casa decimal pra evitar falsa precisão (a fonte de
  /// população já é estimativa de 2010, qualquer precisão maior é teatro).
  double? per10kInhabitants({
    required String? bairro,
    required int count,
  }) {
    final pop = populationFor(bairro);
    if (pop == null || pop <= 0) return null;
    final value = (count * 10000) / pop;
    return double.parse(value.toStringAsFixed(1));
  }

  /// Versão para teste — injeta população direto sem carregar asset.
  static DensityService testWith(Map<String, int> populations) {
    final s = DensityService._();
    s._populationByBairro = {
      for (final e in populations.entries) _normalize(e.key): e.value,
    };
    return s;
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
