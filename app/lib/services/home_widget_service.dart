import 'package:flutter/services.dart' show MethodChannel;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';

import '../core/log/faro_logger.dart';
import '../models/occurrence.dart';
import '../models/user_profile.dart';
import 'occurrences_service.dart';
import 'user_profile_service.dart';

/// Atualiza o widget de tela inicial (iOS + Android) com o que rolou nas
/// últimas 6h no bairro principal do usuário.
///
/// Princípios:
/// - Atualização passiva: o app dispara `updateWidget()` quando há
///   ocorrências novas ou quando o perfil muda. Widget não tem rede própria.
/// - Sem PII: o widget storage guarda só count + nome do bairro + timestamp
///   da última atualização. Sem coordenadas, sem ids de ocorrências.
/// - Silêncio honesto: se o user não tem mainNeighborhood definido, escreve
///   `count = -1` e o widget mostra "configure no app".
class HomeWidgetService {
  static const _log = FaroLogger('home-widget');

  /// IDs únicos do widget. Precisam casar com os providers nativos:
  ///   Android: `FaroWidgetProvider` (kotlin)
  ///   iOS:     `FaroWidget` (swift, kind="FaroWidget")
  static const _androidWidgetName = 'FaroWidgetProvider';
  static const _iosWidgetName = 'FaroWidget';
  static const _appGroupId = 'group.com.faro.faro';

  /// App Group + suite name — preciso pro iOS comunicar entre app e
  /// extension. No Android é ignorado (usa SharedPreferences padrão).
  Future<void> initialize() async {
    try {
      await HomeWidget.setAppGroupId(_appGroupId);
    } catch (e, s) {
      _log.error('home_widget init falhou', e, s);
    }
  }

  /// Atualiza o widget com o estado do app.
  Future<void> updateWidget({
    required UserProfile profile,
    required List<Occurrence> recent,
  }) async {
    try {
      final neighborhood = profile.mainNeighborhood;
      if (neighborhood == null || neighborhood.trim().isEmpty) {
        await _saveState(count: -1, label: '');
      } else {
        final count = _countInLastHours(
          recent,
          neighborhood: neighborhood,
          hours: 6,
        );
        await _saveState(count: count, label: neighborhood);
      }
      await HomeWidget.updateWidget(
        name: _androidWidgetName,
        androidName: _androidWidgetName,
        iOSName: _iosWidgetName,
      );
    } catch (e, s) {
      _log.error('updateWidget falhou', e, s);
    }
  }

  Future<void> _saveState({required int count, required String label}) async {
    await HomeWidget.saveWidgetData<int>('count', count);
    await HomeWidget.saveWidgetData<String>('label', label);
    await HomeWidget.saveWidgetData<String>(
      'updatedAt',
      DateTime.now().toIso8601String(),
    );
  }

  /// Conta ocorrências no bairro (acento-insensitive) nas últimas N horas.
  /// Pura — testável.
  static int _countInLastHours(
    List<Occurrence> recent, {
    required String neighborhood,
    required int hours,
  }) {
    final cutoff = DateTime.now().subtract(Duration(hours: hours));
    final target = _normalize(neighborhood);
    var count = 0;
    for (final o in recent) {
      if (o.date.isBefore(cutoff)) continue;
      if (_normalize(o.neighborhood ?? '') != target) continue;
      count++;
    }
    return count;
  }

  static String _normalize(String s) =>
      s.toLowerCase().normalize().replaceAll(' ', '');
}

extension on String {
  String normalize() {
    // Remove acentos via Unicode decomposition. Mantém ASCII.
    return Runes(this)
        .map((r) => String.fromCharCode(r))
        .join()
        .split('')
        .map((c) => c)
        .join()
        .replaceAll(RegExp(r'[àáâãä]'), 'a')
        .replaceAll(RegExp(r'[èéêë]'), 'e')
        .replaceAll(RegExp(r'[ìíîï]'), 'i')
        .replaceAll(RegExp(r'[òóôõö]'), 'o')
        .replaceAll(RegExp(r'[ùúûü]'), 'u')
        .replaceAll(RegExp(r'ç'), 'c')
        .replaceAll(RegExp(r'ñ'), 'n');
  }
}

final homeWidgetServiceProvider = Provider<HomeWidgetService>(
  (_) => HomeWidgetService(),
);

/// Provider de side-effect: assina mudanças no perfil + ocorrências
/// recentes e dispara `updateWidget` quando algo muda. Manter `keepAlive`
/// pra não ser descartado entre rebuilds.
final homeWidgetSyncProvider = Provider<void>((ref) {
  final service = ref.watch(homeWidgetServiceProvider);
  ref.listen(userProfileProvider, (_, next) {
    next.whenData((profile) {
      ref.read(recentOccurrencesProvider).whenData((occs) {
        service.updateWidget(profile: profile, recent: occs);
      });
    });
  });
  ref.listen(recentOccurrencesProvider, (_, next) {
    next.whenData((occs) {
      ref.read(userProfileProvider).whenData((profile) {
        service.updateWidget(profile: profile, recent: occs);
      });
    });
  });
});

// Stub pra MethodChannel manual no futuro (deep link no tap do widget).
// ignore: unused_element
const _appLinkChannel = MethodChannel('faro.widget/launch');
