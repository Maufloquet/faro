library;

/// Frases-âncora editoriais reaproveitadas em várias telas.
///
/// Centralizar aqui garante:
/// 1. Mudança de tom (ex.: refinar "nunca dizemos seguro" pra "não medimos
///    segurança") aplica em todas as telas de uma vez.
/// 2. Texto repetido fica visivelmente único — evita drift onde a tela
///    Onboarding fala X e a tela Sobre fala "quase X".
/// 3. Quando rolar internacionalização no futuro, **estas constantes são
///    os pontos de tradução** — basta substituí-las por chaves de i18n.
///
/// Pra adicionar nova string: prefira que seja USADA EM 2+ LUGARES.
/// Strings que só aparecem 1x não precisam virar constante — fica inline.
class FaroEditorial {
  FaroEditorial._();

  // ─── Princípios fundadores ─────────────────────────────────────────────
  /// O Faro não afirma segurança. Mensagem-chave do produto.
  static const String neverConfirmsSafety =
      'O Faro não diz que está seguro';

  static const String silentDataIsNotSilentStreet =
      'Silêncio nos dados não é silêncio nas ruas';

  static const String contextNotVerdict =
      'É contexto, não veredito';

  static const String maintainAttention = 'Mantenha atenção sempre.';

  // ─── Disclaimers ───────────────────────────────────────────────────────
  /// Bloco fixo no detalhe de ocorrência. Sempre rodapé.
  static const String reportDisclaimer =
      'Relato baseado em fonte pública. O Faro não garante segurança em '
      'nenhuma região — só comunica o que foi reportado. Erros acontecem.';

  /// Disclaimer da listagem "Atividade por área". Refresca o leitor de
  /// que mais relatos != mais crime real.
  static const String areasRankingDisclaimer =
      'Mais relatos numa área podem indicar mais policiamento ativo, mais '
      'cobertura de mídia ou mais pessoas reportando — não necessariamente '
      'mais crime real. Use como contexto, não como julgamento.';

  /// Disclaimer da seção "Linhas de ônibus citadas".
  static const String busLinesDisclaimer =
      'Linhas mencionadas em matérias de jornal sobre relatos do período. '
      'NÃO é ranking de linha perigosa — pessoa que depende da linha não '
      'pode trocar. Use pra se preparar (escolher horário, descer um ponto '
      'antes ou depois).';

  /// Disclaimer da seção "Quando acontecem" (padrão temporal).
  static const String temporalDisclaimer =
      'Padrão temporal dos relatos do período. NÃO é "evite esse horário" — '
      'quem precisa sair à noite não tem essa escolha. Use pra escolher '
      'quando der flexibilidade.';

  // ─── Privacidade / cadastro ────────────────────────────────────────────
  static const String noSignupNeeded =
      'Você não precisa criar conta. Não pedimos email, nome ou telefone. '
      'Seu uso é anônimo.';

  static const String locationStaysWithYou =
      'Usamos GPS só pra mostrar o que está perto. Não armazenamos seu '
      'histórico individual de trajetos.';
}
