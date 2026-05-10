/// Data source de desenvolvimento — lê ocorrências reais do Fogo Cruzado
/// armazenadas em assets/dev_occurrences.json (snapshot da Validação 2).
///
/// Permite rodar o app localmente antes do Firebase estar configurado.
/// Quando o Firebase entrar, o flag USE_DEV_DATA passa a false e a fonte
/// vira o Firestore (services/occurrences_service.dart).
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/occurrence.dart';

const _assetPath = 'assets/dev_occurrences.json';

Future<List<Occurrence>> _loadFromAsset() async {
  final raw = await rootBundle.loadString(_assetPath);
  final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
  return list.map(_mapOne).whereType<Occurrence>().toList();
}

double? _toDouble(Object? v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

Occurrence? _mapOne(Map<String, dynamic> o) {
  final lat = _toDouble(o['latitude']);
  final lng = _toDouble(o['longitude']);
  if (lat == null || lng == null) return null;

  return Occurrence(
    id: (o['id'] ?? '').toString(),
    latitude: lat,
    longitude: lng,
    date: DateTime.tryParse(o['date']?.toString() ?? '') ?? DateTime.now(),
    state: (o['state'] as Map<String, dynamic>?)?['name'] as String?,
    city: (o['city'] as Map<String, dynamic>?)?['name'] as String?,
    neighborhood: (o['neighborhood'] as Map<String, dynamic>?)?['name'] as String?,
    mainReason: ((o['contextInfo'] as Map<String, dynamic>?)?['mainReason']
        as Map<String, dynamic>?)?['name'] as String?,
    source: 'fogo_cruzado',
    weight: 0.7,
  );
}

Stream<List<Occurrence>> devOccurrencesStream() async* {
  final items = await _loadFromAsset();
  yield items;
}
