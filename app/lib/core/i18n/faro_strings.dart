library;

import 'package:flutter/widgets.dart';

import '../filters/time_window.dart';
import '../theme/app_theme.dart';

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

  // ─── About screen ─────────────────────────────────────────────────────
  static String get aboutTitle => _t('about.title');

  static String get aboutBgAlertsTitle => _t('about.bg_alerts.title');
  static String get aboutBgAlertsBodyOn => _t('about.bg_alerts.body_on');
  static String get aboutBgAlertsBodyOff => _t('about.bg_alerts.body_off');
  static String get aboutPermLocationAlwaysNeeded =>
      _t('about.perm.location_always');
  static String get aboutPermNotifNeeded => _t('about.perm.notif');
  static String get aboutBgAlertsStartFailed => _t('about.bg_alerts.start_failed');

  static String get aboutRefTitle => _t('about.reference.title');
  static String get aboutRefEmpty => _t('about.reference.empty');
  static String aboutRefActive(String label) =>
      _t('about.reference.active').replaceAll('{label}', label);
  static String get aboutRefLocationNeeded =>
      _t('about.reference.location_needed');
  static String get aboutRefSaved => _t('about.reference.saved');
  static String get aboutRefSaveFailed => _t('about.reference.save_failed');
  static String get aboutRefRemoved => _t('about.reference.removed');
  static String get aboutRefDialogTitle => _t('about.reference.dialog.title');
  static String get aboutRefDialogHint => _t('about.reference.dialog.hint');
  static String get aboutRefDialogDefault =>
      _t('about.reference.dialog.default_label');
  static String get aboutRefDialogFallback =>
      _t('about.reference.dialog.fallback_label');
  static String get aboutRefCancel => _t('about.reference.cancel');
  static String get aboutRefSave => _t('about.reference.save');
  static String get aboutRefRemove => _t('about.reference.remove');
  static String get aboutRefUseCurrent => _t('about.reference.use_current');
  static String get aboutRefSwap => _t('about.reference.swap');

  static String get aboutSectionWhatWeAreTitle =>
      _t('about.section.what_we_are.title');
  static String get aboutSectionWhatWeAreBody =>
      _t('about.section.what_we_are.body');
  static String get aboutSectionWhatWeAreNotTitle =>
      _t('about.section.what_we_are_not.title');
  static String get aboutSectionWhatWeAreNotBody =>
      _t('about.section.what_we_are_not.body');
  static String get aboutSectionNoSignupTitle =>
      _t('about.section.no_signup.title');
  static String get aboutSectionNoSignupBody =>
      _t('about.section.no_signup.body');
  static String get aboutSectionSourcesTitle =>
      _t('about.section.sources.title');
  static String get aboutSectionSourcesBody => _t('about.section.sources.body');
  static String get aboutSectionPrivacyTitle =>
      _t('about.section.privacy.title');
  static String get aboutSectionPrivacyBody =>
      _t('about.section.privacy.body');
  static String get aboutSectionHowToUseTitle =>
      _t('about.section.how_to_use.title');
  static String get aboutSectionHowToUseBody =>
      _t('about.section.how_to_use.body');
  static String get aboutSectionContactTitle =>
      _t('about.section.contact.title');
  static String get aboutSectionContactBody =>
      _t('about.section.contact.body');

  static String get aboutTechDetailsTitle => _t('about.tech.title');
  static String get aboutTechDetailsSubtitle => _t('about.tech.subtitle');
  static String get aboutTechRiskTitle => _t('about.tech.risk.title');
  static String get aboutTechRiskBody => _t('about.tech.risk.body');
  static String get aboutTechBiasTitle => _t('about.tech.bias.title');
  static String get aboutTechBiasBody => _t('about.tech.bias.body');
  static String get aboutTechDensityTitle => _t('about.tech.density.title');
  static String get aboutTechDensityBody => _t('about.tech.density.body');

  static String get aboutVersion => _t('about.version');

  // ─── Enums localizados (TimeWindow, RiskLevel) ────────────────────────
  static String timeWindowLabel(TimeWindow w) {
    switch (w) {
      case TimeWindow.hoje:
        return _t('window.today');
      case TimeWindow.semana:
        return _t('window.week');
      case TimeWindow.mes:
        return _t('window.month');
      case TimeWindow.tudo:
        return _t('window.all');
    }
  }

  static String riskLabel(RiskLevel r) {
    switch (r) {
      case RiskLevel.noData:
        return _t('risk.no_data');
      case RiskLevel.noRecentReports:
        return _t('risk.no_recent');
      case RiskLevel.lightActivity:
        return _t('risk.light');
      case RiskLevel.confirmedActivity:
        return _t('risk.confirmed');
      case RiskLevel.highCorroborated:
        return _t('risk.high');
    }
  }

  // ─── Mapa (header, snackbars, marcadores) ─────────────────────────────
  static String get mapSearchHint => _t('map.search_hint');
  static String get mapAreasTooltip => _t('map.areas_tooltip');
  static String get mapLocationFailed => _t('map.location_failed');
  static String get mapBusStop => _t('map.bus_stop');
  static String get mapBusStopShelter => _t('map.bus_stop.shelter');
  static String get mapBusStopBench => _t('map.bus_stop.bench');
  static String get mapBusStopLit => _t('map.bus_stop.lit');
  static String get mapBusStopNoInfra => _t('map.bus_stop.no_infra');

  // ─── Bottom sheet do mapa ─────────────────────────────────────────────
  static String get sheetLoading => _t('sheet.loading');
  static String sheetError(String detail) =>
      _t('sheet.error').replaceAll('{e}', detail);
  static String get sheetScopeAll => _t('sheet.scope.all');
  static String sheetScopeIn(String window) =>
      _t('sheet.scope.in').replaceAll('{window}', window);
  static String sheetEmptyTitle(String scope) =>
      _t('sheet.empty.title').replaceAll('{scope}', scope);
  static String get sheetEmptyBody => _t('sheet.empty.body');
  static String get sheetEmptyButton => _t('sheet.empty.button');
  static String sheetSummaryEmpty(String scope) =>
      _t('sheet.summary.empty').replaceAll('{scope}', scope);
  static String sheetSummaryCount(int count, String scope) {
    final key = count == 1 ? 'sheet.summary.one' : 'sheet.summary.many';
    return _t(key)
        .replaceAll('{count}', count.toString())
        .replaceAll('{scope}', scope);
  }
  static String get sheetSummaryDisclaimer => _t('sheet.summary.disclaimer');
  static String get sheetFooterSource => _t('sheet.footer.source');
  static String sheetFooterFreshMinutes(int min) =>
      _t('sheet.footer.fresh_min').replaceAll('{n}', min.toString());
  static String sheetFooterFreshHours(int h) =>
      _t('sheet.footer.fresh_h').replaceAll('{n}', h.toString());
  static String sheetFooterFreshDays(int d) =>
      _t('sheet.footer.fresh_d').replaceAll('{n}', d.toString());

  // ─── Filtros (pill + sheet) ───────────────────────────────────────────
  static String get filterAllTypes => _t('filter.all_types');
  static String filterMore(String first, int extra) =>
      _t('filter.more')
          .replaceAll('{first}', first)
          .replaceAll('{n}', extra.toString());
  static String get filterPeriod => _t('filter.period');
  static String get filterReason => _t('filter.reason');
  static String get filterClear => _t('filter.clear');
  static String get filterReasonEmpty => _t('filter.reason_empty');
  static String get filterApply => _t('filter.apply');

  // ─── Camadas (layers sheet) ───────────────────────────────────────────
  static String get layersMapType => _t('layers.map_type');
  static String get layersMapTypeNormal => _t('layers.map_type.normal');
  static String get layersMapTypeHybrid => _t('layers.map_type.hybrid');
  static String get layersLayers => _t('layers.layers');
  static String get layersBusStops => _t('layers.bus_stops');
  static String get layersBusStopsHint => _t('layers.bus_stops.hint');
  static String get layersView => _t('layers.view');
  static String get layersTrajectoryTitle => _t('layers.trajectory.title');
  static String get layersTrajectoryHint => _t('layers.trajectory.hint');
  static String get layersApply => _t('layers.apply');

  // ─── Banner de proximidade ────────────────────────────────────────────
  static String get bannerOneTitle => _t('banner.one_title');
  static String bannerManyTitle(int n) =>
      _t('banner.many_title').replaceAll('{n}', n.toString());
  static String bannerOneSubtext(String reason, String when) =>
      _t('banner.one_subtext')
          .replaceAll('{reason}', reason)
          .replaceAll('{when}', when);
  static String bannerManySubtext(String reason, String when) =>
      _t('banner.many_subtext')
          .replaceAll('{reason}', reason)
          .replaceAll('{when}', when);
  static String get bannerReportFallback => _t('banner.report_fallback');
  static String get bannerReportFallbackLower => _t('banner.report_fallback_lower');
  static String bannerWhenMinutes(int m) =>
      _t('banner.when_min').replaceAll('{n}', m.toString());
  static String bannerWhenHours(int h) =>
      _t('banner.when_h').replaceAll('{n}', h.toString());
  static String get bannerDismiss => _t('banner.dismiss');

  // ─── Ocorrência (tile + detail sheet) ─────────────────────────────────
  static String get occNoLocation => _t('occ.no_location');
  static String get occReportFallback => _t('occ.report_fallback');
  static String occRelMinutes(int m) =>
      _t('occ.rel_min').replaceAll('{n}', m.toString());
  static String occRelHours(int h) =>
      _t('occ.rel_h').replaceAll('{n}', h.toString());
  static String occRelDays(int d) =>
      _t('occ.rel_d').replaceAll('{n}', d.toString());
  static String get occMediaFallback => _t('occ.media_fallback');
  static String get occFogoCruzadoLabel => _t('occ.fogo_cruzado');
  static String get occApproxLocation => _t('occ.approx_location');
  static String get occLabelReason => _t('occ.label.reason');
  static String get occLabelWhen => _t('occ.label.when');
  static String get occLabelVisual => _t('occ.label.visual');
  static String get occLabelBusLine => _t('occ.label.bus_line');
  static String get occLabelBusLineHint => _t('occ.label.bus_line_hint');
  static String get occLabelLocation => _t('occ.label.location');
  static String get occApproxValue => _t('occ.approx_value');
  static String get occApproxHint => _t('occ.approx_hint');
  static String get occReadFullStory => _t('occ.read_full');
  static String get occChallenge => _t('occ.challenge');
  static String get occOpenLinkFailed => _t('occ.open_link_failed');
  static String get occChallengeSubmitted => _t('occ.challenge_submitted');
  static String get occLabelSource => _t('occ.label.source');
  static String get occSourceFcHint => _t('occ.source.fc_hint');
  static String get occSourceMediaHint => _t('occ.source.media_hint');
  static String get occSourceUserValue => _t('occ.source.user_value');
  static String get occSourceUserHint => _t('occ.source.user_hint');
  static String get occSourceUnknown => _t('occ.source.unknown');
  static String get occAbsoluteAt => _t('occ.absolute_at');
  static String get occDisclaimer => _t('occ.disclaimer');
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
    'about.title': 'Sobre o Faro',
    'about.bg_alerts.title': 'Alertar com o app fechado',
    'about.bg_alerts.body_on':
        'Faro está atento à sua região. Avisa se houver relatos recentes próximos.',
    'about.bg_alerts.body_off':
        'Receba uma notificação ao entrar em regiões com relatos recentes. Usa GPS em segundo plano.',
    'about.perm.location_always':
        'Permissão de localização "Sempre" necessária.',
    'about.perm.notif': 'Permissão de notificação necessária.',
    'about.bg_alerts.start_failed':
        'Não foi possível iniciar o monitoramento agora.',
    'about.reference.title': 'Local de referência',
    'about.reference.empty':
        'Salve um lugar fixo (hotel, casa, trabalho) e o Faro avisa quando aparecer relato por lá — mesmo se você estiver longe agora.',
    'about.reference.active': '{label} · alertando o entorno deste ponto',
    'about.reference.location_needed':
        'Permissão de localização necessária pra salvar este local.',
    'about.reference.saved': 'Local salvo. Faro vai te avisar de relatos por aqui.',
    'about.reference.save_failed': 'Não foi possível salvar agora. Tente novamente.',
    'about.reference.removed': 'Local removido.',
    'about.reference.dialog.title': 'Como chamar este local?',
    'about.reference.dialog.hint': 'Hotel, Casa, Trabalho...',
    'about.reference.dialog.default_label': 'Hotel',
    'about.reference.dialog.fallback_label': 'Local salvo',
    'about.reference.cancel': 'Cancelar',
    'about.reference.save': 'Salvar',
    'about.reference.remove': 'Remover',
    'about.reference.use_current': 'Usar minha localização',
    'about.reference.swap': 'Trocar',
    'about.section.what_we_are.title': 'O que somos',
    'about.section.what_we_are.body':
        'Um assistente de decisão urbana em tempo real. Mostramos o que está acontecendo perto de você combinando fontes públicas e (futuramente) relatos de usuários. Não somos um mapa de crimes. Não substituímos sua atenção.',
    'about.section.what_we_are_not.title': 'O que não somos',
    'about.section.what_we_are_not.body':
        'Não somos um produto de garantia. Nunca dizemos "está seguro". A única mensagem possível em uma região sem relatos é "sem relatos recentes" — silêncio nos dados não é silêncio nas ruas. Mantenha atenção sempre.',
    'about.section.no_signup.title': 'Sem cadastro',
    'about.section.no_signup.body':
        'Você não precisa criar conta. Não pedimos seu nome, email ou telefone. Seu uso é anônimo. Não rastreamos seu trajeto. Você abre o app e já está usando — é assim por princípio, não por descuido.',
    'about.section.sources.title': 'Fontes de dados',
    'about.section.sources.body':
        'Hoje: Fogo Cruzado (banco público de violência armada — RJ, PE, BA, PA) + matérias de jornais locais (G1, A Tarde, Correio 24h, iBahia, Bahia Notícias, Tribuna da Bahia, releases da SSP-BA) processadas por IA pra extrair bairro, tipo de relato e linha de ônibus. Próximas: relatos de usuários com validação coletiva e canais públicos do Telegram. Cada fonte com peso diferente.',
    'about.section.privacy.title': 'Privacidade',
    'about.section.privacy.body':
        'Sua localização é usada apenas para mostrar relatos próximos. Não armazenamos seu histórico individual de trajetos. Dados agregados por região, nunca por pessoa. A política de privacidade completa está disponível em desenvolvimento.',
    'about.section.how_to_use.title': 'Como usar o Faro',
    'about.section.how_to_use.body':
        'A tela "Como o Faro funciona" tem caminhos práticos por perfil: passageiro de ônibus, motorista de aplicativo, entregador, visitante. Toque no ícone de informação no canto superior do mapa.',
    'about.section.contact.title': 'Contato',
    'about.section.contact.body':
        'Email: faro@example.com (placeholder — em produção será real). Toda contestação de relato é respondida em até 2h durante o beta.',
    'about.tech.title': 'Detalhes técnicos',
    'about.tech.subtitle':
        'Como classificamos risco · viés algorítmico · fonte da densidade',
    'about.tech.risk.title': 'Como classificamos o risco',
    'about.tech.risk.body':
        'Combinamos peso da fonte, idade do relato e densidade de confirmações. Reportes antigos perdem peso automaticamente. Múltiplas fontes independentes corroborando elevam o nível. Uma única fonte isolada nunca sustenta classificação alta.',
    'about.tech.bias.title': 'Sobre viés algorítmico',
    'about.tech.bias.body':
        'Periferias têm mais policiamento e mais cobertura de mídia — não necessariamente mais crime real. Mais boletins em uma região indicam mais visibilidade, não mais risco. Quando não temos dados suficientes em uma área, dizemos isso explicitamente, em vez de assumir que é seguro.',
    'about.tech.density.title': 'Densidade populacional (em construção)',
    'about.tech.density.body':
        'Quando exibimos "relatos por 10 mil habitantes" em um bairro, usamos população do Censo IBGE 2010 (via PMS/SEMOP), porque o Censo 2022 ainda não publicou agregação por bairro para Salvador. Bairros sem dado de população não mostram normalização — preferimos silêncio honesto a número inventado.',
    'about.version': 'Faro · v0.1.0 (alpha)',
    'window.today': 'Hoje',
    'window.week': '7 dias',
    'window.month': '30 dias',
    'window.all': 'Tudo',
    'risk.no_data': 'Sem dados suficientes nesta região',
    'risk.no_recent': 'Sem relatos nas últimas 24h',
    'risk.light': 'Relatos esparsos. Atenção.',
    'risk.confirmed': 'Relatos confirmados. Avaliar rota alternativa.',
    'risk.high': 'Múltiplos relatos. Evitar se possível.',
    'map.search_hint': 'Buscar bairro em Salvador',
    'map.areas_tooltip': 'Atividade por área',
    'map.location_failed': 'Não foi possível obter sua localização agora.',
    'map.bus_stop': 'Ponto de ônibus',
    'map.bus_stop.shelter': 'cobertura',
    'map.bus_stop.bench': 'banco',
    'map.bus_stop.lit': 'iluminação',
    'map.bus_stop.no_infra': 'sem dados de infraestrutura',
    'sheet.loading': 'Carregando relatos…',
    'sheet.error': 'Erro ao carregar: {e}',
    'sheet.scope.all': 'no histórico carregado',
    'sheet.scope.in': 'em {window}',
    'sheet.empty.title': 'Sem relatos {scope}.',
    'sheet.empty.body':
        'Isso não significa que está seguro — significa que ninguém reportou nada nessa janela. Mantenha atenção.',
    'sheet.empty.button': 'Ver tudo o que temos',
    'sheet.summary.empty': 'Sem relatos{scope}',
    'sheet.summary.one': '{count} relato{scope}',
    'sheet.summary.many': '{count} relatos{scope}',
    'sheet.summary.disclaimer': 'Sem garantia de segurança. Apenas o que foi reportado.',
    'sheet.footer.source': 'Fonte: Fogo Cruzado',
    'sheet.footer.fresh_min': 'Último relato há {n} min',
    'sheet.footer.fresh_h': 'Último relato há {n}h',
    'sheet.footer.fresh_d': 'Último relato há {n}d',
    'filter.all_types': 'todos os tipos',
    'filter.more': '{first} +{n}',
    'filter.period': 'Período',
    'filter.reason': 'Tipo de relato',
    'filter.clear': 'Limpar',
    'filter.reason_empty': 'Sem tipos com relatos neste período.',
    'filter.apply': 'Aplicar',
    'layers.map_type': 'Tipo de mapa',
    'layers.map_type.normal': 'Padrão',
    'layers.map_type.hybrid': 'Satélite',
    'layers.layers': 'Camadas',
    'layers.bus_stops': 'Pontos de ônibus',
    'layers.bus_stops.hint': 'Visíveis ao aproximar o mapa (zoom de rua)',
    'layers.view': 'Ver',
    'layers.trajectory.title': 'Seu trajeto',
    'layers.trajectory.hint':
        'Áreas com relatos por onde você passou nos últimos 7 dias',
    'layers.apply': 'Aplicar',
    'banner.one_title': 'Novo relato perto de você',
    'banner.many_title': '{n} relatos próximos nas últimas 6h',
    'banner.one_subtext': '{reason} · {when}',
    'banner.many_subtext': 'Mais recente: {reason} · {when}',
    'banner.report_fallback': 'Relato',
    'banner.report_fallback_lower': 'relato',
    'banner.when_min': 'há {n} min',
    'banner.when_h': 'há {n}h',
    'banner.dismiss': 'Dispensar',
    'occ.no_location': 'Sem localização específica',
    'occ.report_fallback': 'Relato',
    'occ.rel_min': 'há {n} min',
    'occ.rel_h': 'há {n}h',
    'occ.rel_d': 'há {n}d',
    'occ.media_fallback': 'Mídia',
    'occ.fogo_cruzado': 'Fogo Cruzado',
    'occ.approx_location': 'localização aprox.',
    'occ.label.reason': 'Tipo de relato',
    'occ.label.when': 'Quando',
    'occ.label.visual': 'Estado visual',
    'occ.label.bus_line': 'Linha de ônibus',
    'occ.label.bus_line_hint':
        'Linha mencionada na matéria. Pode ser apenas uma referência geográfica — não significa que toda corrida desta linha tem o mesmo risco.',
    'occ.label.location': 'Localização',
    'occ.approx_value': 'Aproximada (centro da cidade)',
    'occ.approx_hint':
        'Notícia não menciona bairro específico. Pin posicionado no centro da cidade.',
    'occ.read_full': 'Ler matéria completa',
    'occ.challenge': 'Contestar relato',
    'occ.open_link_failed': 'Não foi possível abrir o link.',
    'occ.challenge_submitted': 'Contestação enviada. Será revisada em até 2h.',
    'occ.label.source': 'Fonte',
    'occ.source.fc_hint': 'Banco público de violência armada (RJ, PE, BA, PA)',
    'occ.source.media_hint': 'Notícia coletada e classificada automaticamente',
    'occ.source.user_value': 'Relato de usuário',
    'occ.source.user_hint': 'Reportado por outro usuário do app',
    'occ.source.unknown': 'Não identificada',
    'occ.absolute_at': 'às',
    'occ.disclaimer':
        'Relato baseado em fonte pública. O Faro não garante segurança em nenhuma região — só comunica o que foi reportado. Erros acontecem.',
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
    'about.title': 'About Faro',
    'about.bg_alerts.title': 'Alert me with the app closed',
    'about.bg_alerts.body_on':
        'Faro is watching your area. It will notify you if there are recent reports nearby.',
    'about.bg_alerts.body_off':
        'Get a notification when you enter areas with recent reports. Uses GPS in the background.',
    'about.perm.location_always': '"Always" location permission required.',
    'about.perm.notif': 'Notification permission required.',
    'about.bg_alerts.start_failed': 'Could not start monitoring right now.',
    'about.reference.title': 'Reference location',
    'about.reference.empty':
        'Save a fixed place (hotel, home, work) and Faro will alert you when a report appears there — even if you are far away now.',
    'about.reference.active': '{label} · watching the area around this point',
    'about.reference.location_needed':
        'Location permission needed to save this place.',
    'about.reference.saved': 'Place saved. Faro will alert you about reports here.',
    'about.reference.save_failed': 'Could not save right now. Try again.',
    'about.reference.removed': 'Place removed.',
    'about.reference.dialog.title': 'What should we call this place?',
    'about.reference.dialog.hint': 'Hotel, Home, Work...',
    'about.reference.dialog.default_label': 'Hotel',
    'about.reference.dialog.fallback_label': 'Saved place',
    'about.reference.cancel': 'Cancel',
    'about.reference.save': 'Save',
    'about.reference.remove': 'Remove',
    'about.reference.use_current': 'Use my location',
    'about.reference.swap': 'Change',
    'about.section.what_we_are.title': 'What we are',
    'about.section.what_we_are.body':
        'A real-time urban decision assistant. We show what is happening near you by combining public sources and (later) user reports. We are not a crime map. We do not replace your attention.',
    'about.section.what_we_are_not.title': 'What we are not',
    'about.section.what_we_are_not.body':
        'We are not a guarantee product. We never say "it is safe". In an area with no reports, the only possible message is "no recent reports" — silence in the data is not silence on the streets. Stay alert.',
    'about.section.no_signup.title': 'No sign-up',
    'about.section.no_signup.body':
        'No account required. We do not ask for your name, email or phone. Your use is anonymous. We do not track your trajectory. You open the app and you are already using it — by principle, not by oversight.',
    'about.section.sources.title': 'Data sources',
    'about.section.sources.body':
        'Today: Fogo Cruzado (public database of armed violence — RJ, PE, BA, PA) + local news outlets (G1, A Tarde, Correio 24h, iBahia, Bahia Notícias, Tribuna da Bahia, SSP-BA releases) processed by AI to extract neighborhood, report type and bus line. Coming: user reports with collective validation and public Telegram channels. Each source carries different weight.',
    'about.section.privacy.title': 'Privacy',
    'about.section.privacy.body':
        'Your location is used only to show nearby reports. We do not store your individual movement history. Data is aggregated by region, never by person. The full privacy policy is in development.',
    'about.section.how_to_use.title': 'How to use Faro',
    'about.section.how_to_use.body':
        'The "How Faro works" screen has practical paths by profile: bus passenger, rideshare driver, delivery worker, visitor. Tap the info icon at the top of the map.',
    'about.section.contact.title': 'Contact',
    'about.section.contact.body':
        'Email: faro@example.com (placeholder — will be real in production). Every report dispute gets a response within 2h during the beta.',
    'about.tech.title': 'Technical details',
    'about.tech.subtitle':
        'How we classify risk · algorithmic bias · density source',
    'about.tech.risk.title': 'How we classify risk',
    'about.tech.risk.body':
        'We combine source weight, report age, and confirmation density. Old reports automatically lose weight. Multiple independent sources corroborating raise the level. A single isolated source never sustains a high classification.',
    'about.tech.bias.title': 'About algorithmic bias',
    'about.tech.bias.body':
        'Lower-income areas have more policing and more media coverage — not necessarily more actual crime. More bulletins in a region means more visibility, not more risk. When we lack sufficient data in an area, we say so explicitly rather than assuming it is safe.',
    'about.tech.density.title': 'Population density (in progress)',
    'about.tech.density.body':
        'When we display "reports per 10k inhabitants" in a neighborhood, we use IBGE 2010 Census population (via PMS/SEMOP), because the 2022 Census has not yet published neighborhood-level aggregation for Salvador. Neighborhoods without population data show no normalization — we prefer honest silence over invented numbers.',
    'about.version': 'Faro · v0.1.0 (alpha)',
    'window.today': 'Today',
    'window.week': '7 days',
    'window.month': '30 days',
    'window.all': 'All',
    'risk.no_data': 'Not enough data in this area',
    'risk.no_recent': 'No reports in the last 24h',
    'risk.light': 'Scattered reports. Stay alert.',
    'risk.confirmed': 'Confirmed reports. Consider an alternative route.',
    'risk.high': 'Multiple reports. Avoid if possible.',
    'map.search_hint': 'Search neighborhood in Salvador',
    'map.areas_tooltip': 'Activity by area',
    'map.location_failed': 'Could not get your location right now.',
    'map.bus_stop': 'Bus stop',
    'map.bus_stop.shelter': 'shelter',
    'map.bus_stop.bench': 'bench',
    'map.bus_stop.lit': 'lit',
    'map.bus_stop.no_infra': 'no infrastructure data',
    'sheet.loading': 'Loading reports…',
    'sheet.error': 'Loading error: {e}',
    'sheet.scope.all': 'in the loaded history',
    'sheet.scope.in': 'in {window}',
    'sheet.empty.title': 'No reports {scope}.',
    'sheet.empty.body':
        'This does not mean it is safe — it means nobody reported anything in this window. Stay alert.',
    'sheet.empty.button': 'See everything we have',
    'sheet.summary.empty': 'No reports{scope}',
    'sheet.summary.one': '{count} report{scope}',
    'sheet.summary.many': '{count} reports{scope}',
    'sheet.summary.disclaimer': 'No safety guarantee. Only what has been reported.',
    'sheet.footer.source': 'Source: Fogo Cruzado',
    'sheet.footer.fresh_min': 'Latest report {n} min ago',
    'sheet.footer.fresh_h': 'Latest report {n}h ago',
    'sheet.footer.fresh_d': 'Latest report {n}d ago',
    'filter.all_types': 'all types',
    'filter.more': '{first} +{n}',
    'filter.period': 'Period',
    'filter.reason': 'Report type',
    'filter.clear': 'Clear',
    'filter.reason_empty': 'No types with reports in this period.',
    'filter.apply': 'Apply',
    'layers.map_type': 'Map type',
    'layers.map_type.normal': 'Standard',
    'layers.map_type.hybrid': 'Satellite',
    'layers.layers': 'Layers',
    'layers.bus_stops': 'Bus stops',
    'layers.bus_stops.hint': 'Visible when zoomed in (street level)',
    'layers.view': 'View',
    'layers.trajectory.title': 'Your trajectory',
    'layers.trajectory.hint':
        'Areas with reports that you passed through in the last 7 days',
    'layers.apply': 'Apply',
    'banner.one_title': 'New report near you',
    'banner.many_title': '{n} reports nearby in the last 6h',
    'banner.one_subtext': '{reason} · {when}',
    'banner.many_subtext': 'Most recent: {reason} · {when}',
    'banner.report_fallback': 'Report',
    'banner.report_fallback_lower': 'report',
    'banner.when_min': '{n} min ago',
    'banner.when_h': '{n}h ago',
    'banner.dismiss': 'Dismiss',
    'occ.no_location': 'No specific location',
    'occ.report_fallback': 'Report',
    'occ.rel_min': '{n} min ago',
    'occ.rel_h': '{n}h ago',
    'occ.rel_d': '{n}d ago',
    'occ.media_fallback': 'Media',
    'occ.fogo_cruzado': 'Fogo Cruzado',
    'occ.approx_location': 'approx. location',
    'occ.label.reason': 'Report type',
    'occ.label.when': 'When',
    'occ.label.visual': 'Visual state',
    'occ.label.bus_line': 'Bus line',
    'occ.label.bus_line_hint':
        'Line mentioned in the news article. May only be a geographic reference — it does not mean every ride on this line carries the same risk.',
    'occ.label.location': 'Location',
    'occ.approx_value': 'Approximate (city center)',
    'occ.approx_hint':
        'The news did not mention a specific neighborhood. Pin placed at the city center.',
    'occ.read_full': 'Read full story',
    'occ.challenge': 'Challenge this report',
    'occ.open_link_failed': 'Could not open the link.',
    'occ.challenge_submitted': 'Dispute submitted. Will be reviewed within 2h.',
    'occ.label.source': 'Source',
    'occ.source.fc_hint': 'Public armed-violence database (RJ, PE, BA, PA)',
    'occ.source.media_hint': 'News collected and classified automatically',
    'occ.source.user_value': 'User report',
    'occ.source.user_hint': 'Reported by another app user',
    'occ.source.unknown': 'Unidentified',
    'occ.absolute_at': 'at',
    'occ.disclaimer':
        'Report based on a public source. Faro does not guarantee safety in any area — it only communicates what has been reported. Mistakes happen.',
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
    'about.title': 'Sobre Faro',
    'about.bg_alerts.title': 'Avisar con la app cerrada',
    'about.bg_alerts.body_on':
        'Faro está atento a tu zona. Avisa si hay reportes recientes cerca.',
    'about.bg_alerts.body_off':
        'Recibe una notificación al entrar en zonas con reportes recientes. Usa GPS en segundo plano.',
    'about.perm.location_always':
        'Permiso de ubicación "Siempre" necesario.',
    'about.perm.notif': 'Permiso de notificaciones necesario.',
    'about.bg_alerts.start_failed':
        'No fue posible iniciar el monitoreo ahora.',
    'about.reference.title': 'Ubicación de referencia',
    'about.reference.empty':
        'Guarda un lugar fijo (hotel, casa, trabajo) y Faro te avisa cuando aparezca un reporte por allí — incluso si estás lejos ahora.',
    'about.reference.active': '{label} · vigilando el entorno de este punto',
    'about.reference.location_needed':
        'Permiso de ubicación necesario para guardar este lugar.',
    'about.reference.saved': 'Lugar guardado. Faro te avisará de reportes por aquí.',
    'about.reference.save_failed': 'No fue posible guardar ahora. Intenta de nuevo.',
    'about.reference.removed': 'Lugar eliminado.',
    'about.reference.dialog.title': '¿Cómo llamar a este lugar?',
    'about.reference.dialog.hint': 'Hotel, Casa, Trabajo...',
    'about.reference.dialog.default_label': 'Hotel',
    'about.reference.dialog.fallback_label': 'Lugar guardado',
    'about.reference.cancel': 'Cancelar',
    'about.reference.save': 'Guardar',
    'about.reference.remove': 'Eliminar',
    'about.reference.use_current': 'Usar mi ubicación',
    'about.reference.swap': 'Cambiar',
    'about.section.what_we_are.title': 'Qué somos',
    'about.section.what_we_are.body':
        'Un asistente de decisión urbana en tiempo real. Mostramos lo que está pasando cerca de ti combinando fuentes públicas y (a futuro) reportes de usuarios. No somos un mapa de crímenes. No sustituimos tu atención.',
    'about.section.what_we_are_not.title': 'Qué no somos',
    'about.section.what_we_are_not.body':
        'No somos un producto de garantía. Nunca decimos "es seguro". El único mensaje posible en una zona sin reportes es "sin reportes recientes" — silencio en los datos no es silencio en la calle. Mantén siempre la atención.',
    'about.section.no_signup.title': 'Sin registro',
    'about.section.no_signup.body':
        'No necesitas crear cuenta. No pedimos tu nombre, email ni teléfono. Tu uso es anónimo. No rastreamos tu recorrido. Abres la app y ya la estás usando — por principio, no por descuido.',
    'about.section.sources.title': 'Fuentes de datos',
    'about.section.sources.body':
        'Hoy: Fogo Cruzado (base pública de violencia armada — RJ, PE, BA, PA) + noticias de medios locales (G1, A Tarde, Correio 24h, iBahia, Bahia Notícias, Tribuna da Bahia, comunicados de SSP-BA) procesadas por IA para extraer barrio, tipo de reporte y línea de autobús. Próximamente: reportes de usuarios con validación colectiva y canales públicos de Telegram. Cada fuente con peso distinto.',
    'about.section.privacy.title': 'Privacidad',
    'about.section.privacy.body':
        'Tu ubicación se usa solo para mostrar reportes cercanos. No guardamos tu historial individual de recorridos. Datos agregados por región, nunca por persona. La política de privacidad completa está en desarrollo.',
    'about.section.how_to_use.title': 'Cómo usar Faro',
    'about.section.how_to_use.body':
        'La pantalla "Cómo funciona Faro" tiene caminos prácticos por perfil: pasajero de autobús, conductor de app, repartidor, visitante. Toca el ícono de información en la parte superior del mapa.',
    'about.section.contact.title': 'Contacto',
    'about.section.contact.body':
        'Email: faro@example.com (provisional — será real en producción). Toda impugnación de reporte es respondida en hasta 2h durante el beta.',
    'about.tech.title': 'Detalles técnicos',
    'about.tech.subtitle':
        'Cómo clasificamos el riesgo · sesgo algorítmico · fuente de densidad',
    'about.tech.risk.title': 'Cómo clasificamos el riesgo',
    'about.tech.risk.body':
        'Combinamos peso de la fuente, edad del reporte y densidad de confirmaciones. Los reportes viejos pierden peso automáticamente. Múltiples fuentes independientes que corroboran elevan el nivel. Una sola fuente aislada nunca sostiene una clasificación alta.',
    'about.tech.bias.title': 'Sobre sesgo algorítmico',
    'about.tech.bias.body':
        'Las periferias tienen más vigilancia policial y más cobertura mediática — no necesariamente más crimen real. Más boletines en una región indican más visibilidad, no más riesgo. Cuando no tenemos datos suficientes en una zona, lo decimos explícitamente, en vez de asumir que es segura.',
    'about.tech.density.title': 'Densidad poblacional (en construcción)',
    'about.tech.density.body':
        'Cuando mostramos "reportes por 10 mil habitantes" en un barrio, usamos población del Censo IBGE 2010 (vía PMS/SEMOP), porque el Censo 2022 aún no publica agregación por barrio para Salvador. Barrios sin dato de población no muestran normalización — preferimos silencio honesto a un número inventado.',
    'about.version': 'Faro · v0.1.0 (alpha)',
    'window.today': 'Hoy',
    'window.week': '7 días',
    'window.month': '30 días',
    'window.all': 'Todo',
    'risk.no_data': 'Datos insuficientes en esta zona',
    'risk.no_recent': 'Sin reportes en las últimas 24h',
    'risk.light': 'Reportes dispersos. Atención.',
    'risk.confirmed': 'Reportes confirmados. Evalúa una ruta alternativa.',
    'risk.high': 'Múltiples reportes. Evita si es posible.',
    'map.search_hint': 'Buscar barrio en Salvador',
    'map.areas_tooltip': 'Actividad por zona',
    'map.location_failed': 'No fue posible obtener tu ubicación ahora.',
    'map.bus_stop': 'Parada de autobús',
    'map.bus_stop.shelter': 'techo',
    'map.bus_stop.bench': 'banco',
    'map.bus_stop.lit': 'iluminación',
    'map.bus_stop.no_infra': 'sin datos de infraestructura',
    'sheet.loading': 'Cargando reportes…',
    'sheet.error': 'Error al cargar: {e}',
    'sheet.scope.all': 'en el historial cargado',
    'sheet.scope.in': 'en {window}',
    'sheet.empty.title': 'Sin reportes {scope}.',
    'sheet.empty.body':
        'Esto no significa que sea seguro — significa que nadie reportó nada en esta ventana. Mantén la atención.',
    'sheet.empty.button': 'Ver todo lo que tenemos',
    'sheet.summary.empty': 'Sin reportes{scope}',
    'sheet.summary.one': '{count} reporte{scope}',
    'sheet.summary.many': '{count} reportes{scope}',
    'sheet.summary.disclaimer': 'Sin garantía de seguridad. Solo lo que fue reportado.',
    'sheet.footer.source': 'Fuente: Fogo Cruzado',
    'sheet.footer.fresh_min': 'Último reporte hace {n} min',
    'sheet.footer.fresh_h': 'Último reporte hace {n}h',
    'sheet.footer.fresh_d': 'Último reporte hace {n}d',
    'filter.all_types': 'todos los tipos',
    'filter.more': '{first} +{n}',
    'filter.period': 'Período',
    'filter.reason': 'Tipo de reporte',
    'filter.clear': 'Limpiar',
    'filter.reason_empty': 'Sin tipos con reportes en este período.',
    'filter.apply': 'Aplicar',
    'layers.map_type': 'Tipo de mapa',
    'layers.map_type.normal': 'Estándar',
    'layers.map_type.hybrid': 'Satélite',
    'layers.layers': 'Capas',
    'layers.bus_stops': 'Paradas de autobús',
    'layers.bus_stops.hint': 'Visibles al acercar el mapa (nivel calle)',
    'layers.view': 'Ver',
    'layers.trajectory.title': 'Tu recorrido',
    'layers.trajectory.hint':
        'Zonas con reportes por donde pasaste en los últimos 7 días',
    'layers.apply': 'Aplicar',
    'banner.one_title': 'Nuevo reporte cerca de ti',
    'banner.many_title': '{n} reportes cercanos en las últimas 6h',
    'banner.one_subtext': '{reason} · {when}',
    'banner.many_subtext': 'Más reciente: {reason} · {when}',
    'banner.report_fallback': 'Reporte',
    'banner.report_fallback_lower': 'reporte',
    'banner.when_min': 'hace {n} min',
    'banner.when_h': 'hace {n}h',
    'banner.dismiss': 'Descartar',
    'occ.no_location': 'Sin ubicación específica',
    'occ.report_fallback': 'Reporte',
    'occ.rel_min': 'hace {n} min',
    'occ.rel_h': 'hace {n}h',
    'occ.rel_d': 'hace {n}d',
    'occ.media_fallback': 'Medios',
    'occ.fogo_cruzado': 'Fogo Cruzado',
    'occ.approx_location': 'ubic. aprox.',
    'occ.label.reason': 'Tipo de reporte',
    'occ.label.when': 'Cuándo',
    'occ.label.visual': 'Estado visual',
    'occ.label.bus_line': 'Línea de autobús',
    'occ.label.bus_line_hint':
        'Línea mencionada en la noticia. Puede ser solo una referencia geográfica — no significa que cada viaje de esta línea tenga el mismo riesgo.',
    'occ.label.location': 'Ubicación',
    'occ.approx_value': 'Aproximada (centro de la ciudad)',
    'occ.approx_hint':
        'La noticia no menciona un barrio específico. Pin ubicado en el centro de la ciudad.',
    'occ.read_full': 'Leer noticia completa',
    'occ.challenge': 'Impugnar reporte',
    'occ.open_link_failed': 'No fue posible abrir el enlace.',
    'occ.challenge_submitted': 'Impugnación enviada. Será revisada en hasta 2h.',
    'occ.label.source': 'Fuente',
    'occ.source.fc_hint': 'Base pública de violencia armada (RJ, PE, BA, PA)',
    'occ.source.media_hint': 'Noticia recolectada y clasificada automáticamente',
    'occ.source.user_value': 'Reporte de usuario',
    'occ.source.user_hint': 'Reportado por otro usuario de la app',
    'occ.source.unknown': 'No identificada',
    'occ.absolute_at': 'a las',
    'occ.disclaimer':
        'Reporte basado en una fuente pública. Faro no garantiza la seguridad de ninguna zona — solo comunica lo que fue reportado. Los errores pasan.',
  },
};
