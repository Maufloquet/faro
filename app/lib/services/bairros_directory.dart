import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/text/string_format.dart';

/// Bairro com coordenada do centroide (do OpenStreetMap).
class Bairro {
  final String name;
  final String displayName;
  final double lat;
  final double lng;

  const Bairro({
    required this.name,
    required this.displayName,
    required this.lat,
    required this.lng,
  });

  String get searchKey => _stripAccents(name.toLowerCase());
}

String _stripAccents(String s) {
  const from = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
  const to = 'aaaaaeeeeiiiiooooouuuucn';
  final buf = StringBuffer();
  for (final c in s.split('')) {
    final i = from.indexOf(c);
    buf.write(i == -1 ? c : to[i]);
  }
  return buf.toString();
}

class BairrosDirectory {
  List<Bairro>? _cache;

  Future<List<Bairro>> all() async {
    if (_cache != null) return _cache!;
    final raw = await rootBundle.loadString('assets/bairros_salvador.json');
    final map = jsonDecode(raw) as Map<String, dynamic>;
    final list = <Bairro>[];
    for (final entry in map.entries) {
      final v = entry.value as Map<String, dynamic>;
      final lat = (v['lat'] as num?)?.toDouble();
      final lng = (v['lng'] as num?)?.toDouble();
      if (lat == null || lng == null) continue;
      list.add(Bairro(
        name: entry.key,
        displayName: titleCasePtBr(entry.key),
        lat: lat,
        lng: lng,
      ));
    }
    list.sort((a, b) => a.displayName.compareTo(b.displayName));
    _cache = list;
    return list;
  }

  Future<List<Bairro>> search(String query) async {
    final all_ = await all();
    final q = _stripAccents(query.trim().toLowerCase());
    if (q.isEmpty) return all_;
    return all_.where((b) => b.searchKey.contains(q)).toList();
  }
}

final bairrosDirectoryProvider = Provider<BairrosDirectory>(
  (_) => BairrosDirectory(),
);
