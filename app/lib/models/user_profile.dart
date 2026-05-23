import 'package:cloud_firestore/cloud_firestore.dart';

/// Perfil opcional do usuário do Faro.
///
/// Princípio editorial mantido: tudo opcional, tudo pulável. O app
/// funciona sem nada preenchido. Personalização (resumo diário, rota,
/// widget) usa esses campos quando existem; cai pro comportamento
/// genérico quando não.
///
/// Mora em `/users/{uid}` como campos no topo do doc — mesma rule já
/// existente (só o próprio dono lê/escreve). Quando o usuário troca
/// de anonymous pra Google, `AuthService.signInWithGoogle()` linkifica
/// preservando o UID, então o perfil persiste.
class UserProfile {
  final String? displayName;
  final List<TransportMode> transportModes;
  final List<HourBand> typicalHours;
  /// Slug do bairro principal (casa/morador). `null` = não informado.
  /// Coordenadas detalhadas continuam no `ReferenceLocation` separado —
  /// aqui guardamos só o nome pro resumo editorial.
  final String? mainNeighborhood;
  final String? mainCity;
  final NotificationPrefs notifications;
  final DateTime? updatedAt;

  const UserProfile({
    this.displayName,
    this.transportModes = const [],
    this.typicalHours = const [],
    this.mainNeighborhood,
    this.mainCity,
    this.notifications = const NotificationPrefs(),
    this.updatedAt,
  });

  /// Perfil "vazio" — usuário ainda não preencheu nada. Diferente de
  /// `null` (doc não existe).
  bool get isEmpty =>
      displayName == null &&
      transportModes.isEmpty &&
      typicalHours.isEmpty &&
      mainNeighborhood == null;

  UserProfile copyWith({
    String? displayName,
    List<TransportMode>? transportModes,
    List<HourBand>? typicalHours,
    String? mainNeighborhood,
    String? mainCity,
    NotificationPrefs? notifications,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      displayName: displayName ?? this.displayName,
      transportModes: transportModes ?? this.transportModes,
      typicalHours: typicalHours ?? this.typicalHours,
      mainNeighborhood: mainNeighborhood ?? this.mainNeighborhood,
      mainCity: mainCity ?? this.mainCity,
      notifications: notifications ?? this.notifications,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
        if (displayName != null) 'displayName': displayName,
        'transportModes': transportModes.map((m) => m.id).toList(),
        'typicalHours': typicalHours.map((h) => h.id).toList(),
        if (mainNeighborhood != null) 'mainNeighborhood': mainNeighborhood,
        if (mainCity != null) 'mainCity': mainCity,
        'notifications': notifications.toMap(),
      };

  factory UserProfile.fromMap(Map<String, dynamic> m) {
    return UserProfile(
      displayName: m['displayName'] as String?,
      transportModes: _decodeList(m['transportModes'], TransportMode.fromId),
      typicalHours: _decodeList(m['typicalHours'], HourBand.fromId),
      mainNeighborhood: m['mainNeighborhood'] as String?,
      mainCity: m['mainCity'] as String?,
      notifications: m['notifications'] is Map
          ? NotificationPrefs.fromMap(
              Map<String, dynamic>.from(m['notifications'] as Map),
            )
          : const NotificationPrefs(),
      updatedAt: _toDate(m['updatedAt']),
    );
  }

  factory UserProfile.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) return const UserProfile();
    return UserProfile.fromMap(data);
  }
}

/// Como o usuário se locomove. Multi-select.
enum TransportMode {
  bus('bus', 'Ônibus'),
  metro('metro', 'Metrô'),
  app('app', 'Uber/99/táxi'),
  car('car', 'Carro próprio'),
  walk('walk', 'A pé'),
  bike('bike', 'Bicicleta/moto');

  final String id;
  final String label;
  const TransportMode(this.id, this.label);

  static TransportMode? fromId(String? id) {
    for (final m in TransportMode.values) {
      if (m.id == id) return m;
    }
    return null;
  }
}

/// Faixa horária típica em que o usuário tá na rua. Multi-select.
enum HourBand {
  earlyMorning('early_morning', 'Madrugada/manhã cedo (4h–8h)'),
  daytime('daytime', 'Durante o dia (8h–17h)'),
  earlyEvening('early_evening', 'Fim de tarde (17h–20h)'),
  night('night', 'Noite (20h–meia-noite)'),
  lateNight('late_night', 'Madrugada (0h–4h)');

  final String id;
  final String label;
  const HourBand(this.id, this.label);

  static HourBand? fromId(String? id) {
    for (final h in HourBand.values) {
      if (h.id == id) return h;
    }
    return null;
  }
}

class NotificationPrefs {
  final bool dailyDigest;
  final bool proximityAlert;
  final bool routeWatch;

  const NotificationPrefs({
    this.dailyDigest = true,
    this.proximityAlert = true,
    this.routeWatch = true,
  });

  NotificationPrefs copyWith({
    bool? dailyDigest,
    bool? proximityAlert,
    bool? routeWatch,
  }) {
    return NotificationPrefs(
      dailyDigest: dailyDigest ?? this.dailyDigest,
      proximityAlert: proximityAlert ?? this.proximityAlert,
      routeWatch: routeWatch ?? this.routeWatch,
    );
  }

  Map<String, dynamic> toMap() => {
        'dailyDigest': dailyDigest,
        'proximityAlert': proximityAlert,
        'routeWatch': routeWatch,
      };

  factory NotificationPrefs.fromMap(Map<String, dynamic> m) {
    return NotificationPrefs(
      dailyDigest: m['dailyDigest'] is bool ? m['dailyDigest'] as bool : true,
      proximityAlert:
          m['proximityAlert'] is bool ? m['proximityAlert'] as bool : true,
      routeWatch: m['routeWatch'] is bool ? m['routeWatch'] as bool : true,
    );
  }
}

List<T> _decodeList<T>(Object? raw, T? Function(String?) parser) {
  if (raw is! List) return const [];
  final out = <T>[];
  for (final item in raw) {
    if (item is String) {
      final parsed = parser(item);
      if (parsed != null) out.add(parsed);
    }
  }
  return out;
}

DateTime? _toDate(Object? v) {
  if (v == null) return null;
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  return null;
}
