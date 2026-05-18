library;

import 'package:flutter/widgets.dart';

/// Camada simples de tradução pras frases críticas do Faro.
///
/// Por que não usar `flutter_localizations` + ARB: pra ~30 strings é
/// overkill, vira 4 arquivos de configuração e gera código. Mapa Dart
/// puro cobre o caso, fica auditável e funciona em testes sem setup.
///
/// Como funciona:
/// 1. `FaroStrings.init(locale)` é chamado no boot — detecta idioma
///    do dispositivo (PT/EN/ES). Locale desconhecido vira PT.
/// 2. Cada string é getter que olha `_locale` e retorna a versão certa.
/// 3. Se uma chave não tem tradução pro locale atual, fallback pra PT.
///
/// Pra adicionar string nova: incluir em `_table` nas 3 colunas. Se a
/// versão EN/ES ficar idêntica ao PT, deixar igual mesmo — explicitar
/// é melhor que esconder.
class FaroStrings {
  FaroStrings._();

  static String _locale = 'pt';

  /// Inicializa baseado no locale do device. Chamar no boot do app
  /// **antes** de qualquer leitura de string.
  static void init(Locale locale) {
    final code = locale.languageCode.toLowerCase();
    _locale = const ['en', 'es', 'pt'].contains(code) ? code : 'pt';
  }

  /// Resgata uma string pela chave. Fallback automático: locale → 'pt' → chave.
  static String _t(String key) {
    return _table[_locale]?[key] ?? _table['pt']![key] ?? key;
  }

  // ─── Princípios do onboarding ─────────────────────────────────────────
  static String get onboardingHeadline => _t('onboarding.headline');
  static String get onboardingSubhead => _t('onboarding.subhead');

  static String get principleNeverSafeTitle =>
      _t('principle.never_safe.title');
  static String get principleNeverSafeBody => _t('principle.never_safe.body');

  static String get principleContextTitle => _t('principle.context.title');
  static String get principleContextBody => _t('principle.context.body');

  static String get principleLocationTitle => _t('principle.location.title');
  static String get principleLocationBody => _t('principle.location.body');

  static String get principleNoSignupTitle => _t('principle.no_signup.title');
  static String get principleNoSignupBody => _t('principle.no_signup.body');

  // ─── Aceite e botão ───────────────────────────────────────────────────
  static String get acceptanceText => _t('acceptance.text');
  static String get acceptanceCta => _t('acceptance.cta');

  // ─── Disclaimers genéricos ────────────────────────────────────────────
  static String get silenceDisclaimer => _t('disclaimer.silence');
  static String get notARiskRanking => _t('disclaimer.not_a_ranking');

  // ─── Splash ───────────────────────────────────────────────────────────
  static String get splashTagline => _t('splash.tagline');

  // ─── Busca de bairro ──────────────────────────────────────────────────
  static String get searchTitle => _t('search.title');
  static String get searchHint => _t('search.hint');
  static String get searchLoading => _t('search.loading');
  static String searchEmpty(String query) =>
      _t('search.empty').replaceAll('{q}', query);
}

const Map<String, Map<String, String>> _table = {
  'pt': {
    'onboarding.headline': 'Bem-vindo ao Faro',
    'onboarding.subhead':
        'Antes de começar, quatro coisas que você precisa saber:',
    'principle.never_safe.title': 'O Faro não diz que está seguro',
    'principle.never_safe.body':
        'Mostramos relatos recentes na sua região. Silêncio nos dados não é silêncio nas ruas — mantenha sua atenção sempre.',
    'principle.context.title': 'É contexto, não veredito',
    'principle.context.body':
        'Combinamos dados públicos (Fogo Cruzado), notícias e (em breve) relatos de outros usuários. Cada fonte tem peso editorial diferente.',
    'principle.location.title': 'Sua localização fica com você',
    'principle.location.body':
        'Usamos GPS só pra mostrar o que está perto. Não armazenamos seu histórico individual de trajetos.',
    'principle.no_signup.title': 'Sem cadastro, sem perfil',
    'principle.no_signup.body':
        'Você não precisa criar conta. Não pedimos email, nome ou telefone. Seu uso é anônimo desde o primeiro toque.',
    'acceptance.text':
        'Entendi os princípios acima e concordo em usar o Faro como complemento à minha atenção, não substituto.',
    'acceptance.cta': 'Entendi, abrir o mapa',
    'disclaimer.silence': 'Silêncio nos dados não é silêncio nas ruas',
    'disclaimer.not_a_ranking': 'Isto NÃO é um ranking de risco',
    'splash.tagline': 'O que está acontecendo perto de você agora',
    'search.title': 'Buscar bairro',
    'search.hint': 'Ex: Pirajá, Itapuã, Barra…',
    'search.loading': 'Carregando lista de bairros…',
    'search.empty': 'Nenhum bairro encontrado com "{q}".',
  },
  'en': {
    'onboarding.headline': 'Welcome to Faro',
    'onboarding.subhead': 'Four things you need to know before starting:',
    'principle.never_safe.title': 'Faro never says it is safe',
    'principle.never_safe.body':
        'We show recent reports near you. Silence in the data is not silence on the streets — stay alert.',
    'principle.context.title': 'Context, not verdict',
    'principle.context.body':
        'We combine public data (Fogo Cruzado), news outlets and (soon) user reports. Each source carries different editorial weight.',
    'principle.location.title': 'Your location stays with you',
    'principle.location.body':
        'GPS is used only to show what is nearby. We do not store your individual movement history.',
    'principle.no_signup.title': 'No sign-up, no profile',
    'principle.no_signup.body':
        'No account required. We do not ask for email, name or phone. Your use is anonymous from the first tap.',
    'acceptance.text':
        'I understand the principles above and agree to use Faro as a complement to my attention, not a replacement.',
    'acceptance.cta': 'Got it, open the map',
    'disclaimer.silence': 'Silence in the data is not silence on the streets',
    'disclaimer.not_a_ranking': 'This is NOT a risk ranking',
    'splash.tagline': 'What is happening near you right now',
    'search.title': 'Search neighborhood',
    'search.hint': 'e.g. Pirajá, Itapuã, Barra…',
    'search.loading': 'Loading neighborhood list…',
    'search.empty': 'No neighborhood found for "{q}".',
  },
  'es': {
    'onboarding.headline': 'Bienvenido a Faro',
    'onboarding.subhead': 'Cuatro cosas que necesitas saber antes de empezar:',
    'principle.never_safe.title': 'Faro nunca dice que es seguro',
    'principle.never_safe.body':
        'Mostramos reportes recientes cerca de ti. El silencio en los datos no es silencio en la calle — mantén la atención.',
    'principle.context.title': 'Contexto, no veredicto',
    'principle.context.body':
        'Combinamos datos públicos (Fogo Cruzado), prensa y (pronto) reportes de usuarios. Cada fuente tiene peso editorial distinto.',
    'principle.location.title': 'Tu ubicación queda contigo',
    'principle.location.body':
        'Usamos el GPS solo para mostrar lo que está cerca. No guardamos tu historial individual de recorridos.',
    'principle.no_signup.title': 'Sin registro, sin perfil',
    'principle.no_signup.body':
        'No necesitas crear cuenta. No pedimos email, nombre ni teléfono. Tu uso es anónimo desde el primer toque.',
    'acceptance.text':
        'Entiendo los principios anteriores y acepto usar Faro como complemento a mi atención, no como sustituto.',
    'acceptance.cta': 'Entendido, abrir el mapa',
    'disclaimer.silence': 'El silencio en los datos no es silencio en la calle',
    'disclaimer.not_a_ranking': 'Esto NO es un ranking de riesgo',
    'splash.tagline': 'Lo que está pasando cerca de ti ahora',
    'search.title': 'Buscar barrio',
    'search.hint': 'Ej: Pirajá, Itapuã, Barra…',
    'search.loading': 'Cargando lista de barrios…',
    'search.empty': 'Ningún barrio encontrado para "{q}".',
  },
};
