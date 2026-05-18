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

  // ─── Help screen ──────────────────────────────────────────────────────
  static String get helpTitle => _t('help.title');
  static String get helpAboutTooltip => _t('help.tooltip.about');
  static String get helpHeroTitle => _t('help.hero.title');
  static String get helpHeroBody => _t('help.hero.body');

  static String get helpNotCrimeMapTitle => _t('help.feature.not_crime_map.title');
  static String get helpNotCrimeMapBody => _t('help.feature.not_crime_map.body');
  static String get helpNeverSafeTitle => _t('help.feature.never_safe.title');
  static String get helpNeverSafeBody => _t('help.feature.never_safe.body');
  static String get helpSourcesTitle => _t('help.feature.sources.title');
  static String get helpSourcesBody => _t('help.feature.sources.body');
  static String get helpPrivacyTitle => _t('help.feature.privacy.title');
  static String get helpPrivacyBody => _t('help.feature.privacy.body');

  static String get helpAudienceHeader => _t('help.audience.header');
  static String get helpAudienceSubhead => _t('help.audience.subhead');

  static String get helpBusTitle => _t('help.audience.bus.title');
  static String get helpBusBody => _t('help.audience.bus.body');
  static String get helpDriverTitle => _t('help.audience.driver.title');
  static String get helpDriverBody => _t('help.audience.driver.body');
  static String get helpDeliveryTitle => _t('help.audience.delivery.title');
  static String get helpDeliveryBody => _t('help.audience.delivery.body');
  static String get helpTouristTitle => _t('help.audience.tourist.title');
  static String get helpTouristBody => _t('help.audience.tourist.body');

  static String get helpPrivacyFooter => _t('help.privacy_footer');
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
    'help.title': 'Como o Faro funciona',
    'help.tooltip.about': 'Sobre o Faro',
    'help.hero.title': 'O que está\nacontecendo perto\nde você agora?',
    'help.hero.body':
        'O Faro lê fontes públicas em tempo real e mostra a movimentação do entorno. Ajuda a decidir uma rota, não a confirmar uma certeza.',
    'help.feature.not_crime_map.title': 'Não somos um mapa de crimes',
    'help.feature.not_crime_map.body':
        'Mostramos o que está acontecendo perto de você agora — não estatística histórica. A intenção é ajudar uma decisão pontual: passar por aqui, ou desviar?',
    'help.feature.never_safe.title': 'Nunca afirmamos segurança',
    'help.feature.never_safe.body':
        'A única mensagem possível é "sem relatos recentes nesta área". O app não diz que algum lugar é seguro — só comunica probabilidade e ausência de relatos.',
    'help.feature.sources.title': 'Várias fontes, pesos diferentes',
    'help.feature.sources.body':
        'Hoje usamos dados em tempo real do Fogo Cruzado (RJ, PE, BA, PA). Ao longo da V2 entram relatos de usuários, scraping de portais locais e canais públicos do Telegram — cada fonte com peso próprio.',
    'help.feature.privacy.title': 'Privacidade desde o dia 1',
    'help.feature.privacy.body':
        'Sua localização é usada para mostrar relatos próximos. Não armazenamos histórico individual de trajetos. Dados agregados por região, nunca por pessoa.',
    'help.audience.header': 'Como usar pra cada perfil',
    'help.audience.subhead':
        'Caminhos práticos pensados pra quem usa o app por uma razão específica.',
    'help.audience.bus.title': 'Se você anda de ônibus',
    'help.audience.bus.body':
        'Antes de sair, abra o mapa e use o filtro 24h pra ver o que rolou hoje na região onde vai descer. Em Atividade por Área você vê quais linhas foram citadas em relatos recentes — não pra evitar, pra se preparar (escolher horário, descer um ponto antes ou depois).',
    'help.audience.driver.title': 'Se você é motorista de aplicativo',
    'help.audience.driver.body':
        'Antes de aceitar corrida pra destino desconhecido, busque o bairro no mapa. Em 2 segundos você vê os relatos das últimas 24h. O Faro NÃO recomenda recusar corridas — discriminação territorial é ilegal e viola termos das plataformas. Damos contexto pra decisão, não veredito.',
    'help.audience.delivery.title': 'Se você é entregador',
    'help.audience.delivery.body':
        'Mesmo princípio do motorista: contexto antes da entrega. Em rotas noturnas em áreas pouco familiares, olhe o bairro antes de aceitar. A tela "Atividade por área" mostra onde concentraram relatos nas últimas semanas — útil pra escolher horários de menor exposição.',
    'help.audience.tourist.title': 'Se você está visitando Salvador',
    'help.audience.tourist.body':
        'Vá na tela Sobre e salve seu hotel como "Local de referência". O Faro vai te avisar se houver relatos no entorno dele mesmo quando você estiver longe — útil pra decidir horário de volta ou se vai de Uber ou andando.',
    'help.privacy_footer':
        'Erros acontecem. Quando um relato se mostrar impreciso, ele pode ser contestado e expira automaticamente. O app não substitui sua atenção — só a complementa.',
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
    'help.title': 'How Faro works',
    'help.tooltip.about': 'About Faro',
    'help.hero.title': 'What is\nhappening near\nyou right now?',
    'help.hero.body':
        'Faro reads public sources in real time and shows the activity around you. It helps you decide on a route — not confirm certainty.',
    'help.feature.not_crime_map.title': 'We are not a crime map',
    'help.feature.not_crime_map.body':
        'We show what is happening near you right now — not historical statistics. The goal is to support a specific decision: go this way, or go around?',
    'help.feature.never_safe.title': 'We never claim it is safe',
    'help.feature.never_safe.body':
        'The only possible message is "no recent reports in this area". The app does not say a place is safe — it only signals probability and the absence of reports.',
    'help.feature.sources.title': 'Multiple sources, different weights',
    'help.feature.sources.body':
        'Today we use real-time data from Fogo Cruzado (RJ, PE, BA, PA). Through V2 we are adding user reports, scraping of local outlets, and public Telegram channels — each source carries its own weight.',
    'help.feature.privacy.title': 'Privacy from day one',
    'help.feature.privacy.body':
        'Your location is used to show nearby reports. We do not store your individual movement history. Data is aggregated by region, never by person.',
    'help.audience.header': 'How to use it for each profile',
    'help.audience.subhead':
        'Practical paths designed for people who use the app for a specific reason.',
    'help.audience.bus.title': 'If you ride the bus',
    'help.audience.bus.body':
        'Before heading out, open the map and use the 24h filter to see what happened today in the area where you will get off. In Activity by Area you can see which lines were mentioned in recent reports — not to avoid them, but to prepare (pick a time, get off a stop earlier or later).',
    'help.audience.driver.title': 'If you are a rideshare driver',
    'help.audience.driver.body':
        'Before accepting a ride to an unfamiliar destination, search the neighborhood on the map. In 2 seconds you see reports from the last 24h. Faro does NOT recommend refusing rides — territorial discrimination is illegal and violates platform terms. We give context for the decision, not a verdict.',
    'help.audience.delivery.title': 'If you are a delivery worker',
    'help.audience.delivery.body':
        'Same principle as the driver: context before the delivery. On night routes in unfamiliar areas, check the neighborhood before accepting. "Activity by area" shows where reports have concentrated in recent weeks — useful for picking lower-exposure hours.',
    'help.audience.tourist.title': 'If you are visiting Salvador',
    'help.audience.tourist.body':
        'Go to the About screen and save your hotel as "Reference location". Faro will alert you if there are reports near it even when you are far away — useful for deciding when to head back, or whether to take an Uber or walk.',
    'help.privacy_footer':
        'Mistakes happen. When a report turns out to be inaccurate, it can be challenged and expires automatically. The app does not replace your attention — it complements it.',
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
    'help.title': 'Cómo funciona Faro',
    'help.tooltip.about': 'Sobre Faro',
    'help.hero.title': '¿Qué está\npasando cerca\nde ti ahora?',
    'help.hero.body':
        'Faro lee fuentes públicas en tiempo real y muestra el movimiento del entorno. Ayuda a decidir una ruta, no a confirmar una certeza.',
    'help.feature.not_crime_map.title': 'No somos un mapa de crímenes',
    'help.feature.not_crime_map.body':
        'Mostramos lo que está pasando cerca de ti ahora — no estadísticas históricas. El objetivo es apoyar una decisión puntual: ¿paso por aquí o doy la vuelta?',
    'help.feature.never_safe.title': 'Nunca decimos que es seguro',
    'help.feature.never_safe.body':
        'El único mensaje posible es "sin reportes recientes en esta zona". La app no dice que algún lugar es seguro — solo comunica probabilidad y ausencia de reportes.',
    'help.feature.sources.title': 'Varias fuentes, pesos distintos',
    'help.feature.sources.body':
        'Hoy usamos datos en tiempo real de Fogo Cruzado (RJ, PE, BA, PA). A lo largo de V2 entran reportes de usuarios, scraping de portales locales y canales públicos de Telegram — cada fuente con su propio peso.',
    'help.feature.privacy.title': 'Privacidad desde el día 1',
    'help.feature.privacy.body':
        'Tu ubicación se usa para mostrar reportes cercanos. No guardamos tu historial individual de recorridos. Datos agregados por región, nunca por persona.',
    'help.audience.header': 'Cómo usarlo según tu perfil',
    'help.audience.subhead':
        'Caminos prácticos pensados para quien usa la app por una razón específica.',
    'help.audience.bus.title': 'Si te mueves en autobús',
    'help.audience.bus.body':
        'Antes de salir, abre el mapa y usa el filtro 24h para ver lo que pasó hoy en la zona donde te bajarás. En Actividad por Área verás qué líneas fueron mencionadas en reportes recientes — no para evitarlas, sino para prepararte (elegir horario, bajarte una parada antes o después).',
    'help.audience.driver.title': 'Si eres conductor de app',
    'help.audience.driver.body':
        'Antes de aceptar un viaje a un destino desconocido, busca el barrio en el mapa. En 2 segundos ves los reportes de las últimas 24h. Faro NO recomienda rechazar viajes — la discriminación territorial es ilegal y viola los términos de las plataformas. Damos contexto para la decisión, no veredicto.',
    'help.audience.delivery.title': 'Si eres repartidor',
    'help.audience.delivery.body':
        'Mismo principio que el conductor: contexto antes de la entrega. En rutas nocturnas en zonas poco familiares, mira el barrio antes de aceptar. "Actividad por área" muestra dónde se concentraron reportes en las últimas semanas — útil para elegir horarios de menor exposición.',
    'help.audience.tourist.title': 'Si estás visitando Salvador',
    'help.audience.tourist.body':
        'Ve a la pantalla Sobre y guarda tu hotel como "Ubicación de referencia". Faro te avisará si hay reportes cerca de él incluso cuando estés lejos — útil para decidir el horario de regreso o si vas en Uber o caminando.',
    'help.privacy_footer':
        'Los errores pasan. Cuando un reporte se muestra impreciso, puede ser impugnado y caduca automáticamente. La app no sustituye tu atención — solo la complementa.',
  },
};
