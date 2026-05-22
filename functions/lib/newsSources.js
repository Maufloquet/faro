"use strict";

/**
 * Fontes de notícias monitoradas pela função ingestNewsBahia.
 *
 * Pesos editoriais:
 * - 0.35: portal local consolidado com cobertura ampla
 * - 0.30: portal local secundário OU Google News por query
 * - 0.25: programa de TV sensacionalista (peso menor por viés)
 *
 * Estratégia: Google News RSS é mais estável que RSS dos portais
 * (que mudam HTML/path silenciosamente). Pra portais BNews e
 * Bahia Notícias usamos APENAS Google News porque os RSS diretos
 * não funcionam (verificado em 2026-05-11).
 */

const GOOGLE_NEWS_RSS = (query) =>
  `https://news.google.com/rss/search?q=${encodeURIComponent(query)}&hl=pt-BR&gl=BR&ceid=BR:pt-419`;

const SOURCES = [
  // ─── Portais locais com RSS direto confirmado ───
  {
    id: "g1-bahia",
    name: "G1 Bahia",
    url: "https://g1.globo.com/rss/g1/bahia/",
    enabled: true,
    weight: 0.35,
    scope: "salvador",
  },
  {
    id: "correio24horas",
    name: "Correio 24 Horas",
    url: "https://www.correio24horas.com.br/rss",
    enabled: true,
    weight: 0.35,
    scope: "salvador",
  },
  {
    id: "atarde",
    name: "A Tarde",
    url: "https://www.atarde.com.br/rss",
    enabled: true,
    weight: 0.35,
    scope: "salvador",
  },
  {
    id: "ibahia",
    name: "iBahia",
    url: "https://www.ibahia.com/feed/",
    enabled: true,
    weight: 0.30,
    scope: "salvador",
  },

  // ─── Expansão 2026-05-22: portais validados com RSS ativo ───
  // bnews (Bocão News): /feed retorna RSS válido com Mozilla UA. Mistura
  //   tudo (entretenimento, esporte, política, segurança) — o classificador
  //   Groq descarta o irrelevante. Cobre greve dos rodoviários, operações
  //   policiais, casos cotidianos com forte ênfase em Salvador.
  // bahianoar: feed RSS confirmado, cobertura policial diária forte da
  //   RMS (Alagoinhas, Dias d'Ávila, Salvador, periferia). Match perfeito
  //   pro app — relatos exclusivos que não saem nos grandes portais.
  {
    id: "bocao-news",
    name: "Bocão News (BNews)",
    url: "https://www.bnews.com.br/feed",
    enabled: true,
    weight: 0.30,
    scope: "salvador",
  },
  {
    id: "bahia-no-ar",
    name: "Bahia no Ar",
    url: "https://bahianoar.com/feed/",
    enabled: true,
    weight: 0.30,
    scope: "salvador",
  },

  // ─── RSS verificados sem itens (mantidos como referência) ───
  // bahia-noticias: RSS oficial em /quem-somos/rss.xml retorna <channel>
  //   vazio (sem <item>). Cobertura continua via gnews-bahia-noticias.
  // metropoles-ba: feed nacional sem segmentação por estado.
  {
    id: "bahia-noticias",
    name: "Bahia Notícias",
    url: "https://www.bahianoticias.com.br/quem-somos/rss.xml",
    enabled: false,
    weight: 0.30,
    scope: "salvador",
  },
  {
    id: "metropoles-ba",
    name: "Metrópoles - Bahia",
    url: "https://www.metropoles.com/feed/?cat=brasil",
    enabled: false,
    weight: 0.30,
    scope: "salvador",
  },

  // ─── Google News por tipo de ocorrência (cobertura cruzada) ───
  {
    id: "gnews-tiroteio-salvador",
    name: "Google News · tiroteio Salvador",
    url: GOOGLE_NEWS_RSS("tiroteio Salvador BA"),
    enabled: true,
    weight: 0.30,
    scope: "salvador",
  },
  {
    id: "gnews-homicidio-salvador",
    name: "Google News · homicídio Salvador",
    url: GOOGLE_NEWS_RSS("homicídio Salvador BA bairro"),
    enabled: true,
    weight: 0.30,
    scope: "salvador",
  },
  {
    id: "gnews-operacao-salvador",
    name: "Google News · operação policial Salvador",
    url: GOOGLE_NEWS_RSS("operação policial Salvador BA"),
    enabled: true,
    weight: 0.30,
    scope: "salvador",
  },
  {
    id: "gnews-assalto-salvador",
    name: "Google News · assalto Salvador",
    url: GOOGLE_NEWS_RSS("assalto Salvador BA bairro"),
    enabled: true,
    weight: 0.30,
    scope: "salvador",
  },
  {
    id: "gnews-roubo-salvador",
    name: "Google News · roubo Salvador",
    url: GOOGLE_NEWS_RSS("roubo Salvador BA"),
    enabled: true,
    weight: 0.30,
    scope: "salvador",
  },

  // ─── RMS — cidades vizinhas de Salvador ───
  {
    id: "gnews-violencia-camacari",
    name: "Google News · violência Camaçari",
    url: GOOGLE_NEWS_RSS("violência OR assalto OR tiroteio Camaçari"),
    enabled: true,
    weight: 0.30,
    scope: "camacari",
  },
  {
    id: "gnews-violencia-lauro",
    name: "Google News · violência Lauro de Freitas",
    url: GOOGLE_NEWS_RSS("violência OR assalto OR tiroteio \"Lauro de Freitas\""),
    enabled: true,
    weight: 0.30,
    scope: "lauro_de_freitas",
  },
  {
    id: "gnews-violencia-simoes",
    name: "Google News · violência Simões Filho",
    url: GOOGLE_NEWS_RSS("violência OR assalto OR tiroteio \"Simões Filho\""),
    enabled: true,
    weight: 0.30,
    scope: "simoes_filho",
  },

  // ─── Google News por portal (cobre os RSS diretos quebrados) ───
  {
    id: "gnews-bocao-news",
    name: "Google News · Bocão News / BNews",
    url: GOOGLE_NEWS_RSS("\"bocão news\" OR \"bnews\" Salvador"),
    enabled: true,
    weight: 0.30,
    scope: "salvador",
  },
  {
    id: "gnews-bahia-noticias",
    name: "Google News · Bahia Notícias",
    url: GOOGLE_NEWS_RSS("\"bahia notícias\" Salvador"),
    enabled: true,
    weight: 0.30,
    scope: "salvador",
  },
  {
    id: "gnews-metropoles-ba",
    name: "Google News · Metrópoles BA",
    url: GOOGLE_NEWS_RSS("metrópoles Salvador Bahia"),
    enabled: true,
    weight: 0.30,
    scope: "salvador",
  },
  // HojeBahia — portal local relevante, RSS direto retorna 403 (anti-bot),
  // então cobrimos via Google News.
  {
    id: "gnews-hoje-bahia",
    name: "Google News · Hoje Bahia",
    url: GOOGLE_NEWS_RSS("\"hoje bahia\" Salvador"),
    enabled: true,
    weight: 0.30,
    scope: "salvador",
  },
  // Bahia.ba — portal mais novo, ainda sem RSS direto confirmado.
  {
    id: "gnews-bahia-ba",
    name: "Google News · Bahia.ba",
    url: GOOGLE_NEWS_RSS("\"bahia.ba\" Salvador segurança"),
    enabled: true,
    weight: 0.30,
    scope: "salvador",
  },
  // Tribuna da Bahia — RSS direto não confirmado, cobrimos via Google News.
  {
    id: "gnews-tribuna-bahia",
    name: "Google News · Tribuna da Bahia",
    url: GOOGLE_NEWS_RSS("\"tribuna da bahia\" Salvador"),
    enabled: true,
    weight: 0.30,
    scope: "salvador",
  },

  // ─── Releases oficiais (peso maior, sem sensacionalismo) ───
  //
  // Notícias oficiais da SSP-BA são releases institucionais sobre operações,
  // apreensões e prisões. Tom factual (não-sensacionalista) — peso editorial
  // levemente maior. Trade-off: ponto de vista da polícia, então combina
  // com cobertura de jornais críticos pra evitar viés institucional.
  {
    id: "gnews-ssp-ba",
    name: "Google News · SSP-BA (releases oficiais)",
    url: GOOGLE_NEWS_RSS("site:ssp.ba.gov.br OR site:ba.gov.br/ssp Salvador"),
    enabled: true,
    weight: 0.35,
    scope: "salvador",
  },

  // ─── Programas populares (peso menor por viés sensacionalista) ───
  //
  // Mantemos peso 0.25 nesses canais pra não dominarem o cálculo de
  // risco. Classificador filtra por security_related, mas a cobertura
  // deles tende a amplificar estigma territorial.
  {
    id: "gnews-alo-juca",
    name: "Google News · Alô Juca (Record Itapoan)",
    url: GOOGLE_NEWS_RSS("\"alô juca\" Salvador"),
    enabled: true,
    weight: 0.25,
    scope: "salvador",
  },
  {
    id: "gnews-balanco-geral",
    name: "Google News · Balanço Geral BA",
    url: GOOGLE_NEWS_RSS("\"balanço geral\" Salvador Bahia"),
    enabled: true,
    weight: 0.25,
    scope: "salvador",
  },
  {
    id: "gnews-cidade-alerta",
    name: "Google News · Cidade Alerta BA",
    url: GOOGLE_NEWS_RSS("\"cidade alerta\" Salvador Bahia"),
    enabled: true,
    weight: 0.25,
    scope: "salvador",
  },
  {
    id: "gnews-bahia-no-ar",
    name: "Google News · Bahia no Ar (TV Aratu)",
    url: GOOGLE_NEWS_RSS("\"bahia no ar\" Salvador"),
    enabled: true,
    weight: 0.25,
    scope: "salvador",
  },
  {
    id: "gnews-massa",
    name: "Google News · Massa! (SBT)",
    url: GOOGLE_NEWS_RSS("\"massa\" SBT Bahia Salvador"),
    enabled: true,
    weight: 0.25,
    scope: "salvador",
  },

  // ─── Nacionais (cobertura quando incidente vira pauta nacional) ───
  {
    id: "g1-brasil",
    name: "G1 Brasil",
    url: "https://g1.globo.com/rss/g1/brasil/",
    enabled: false,
    weight: 0.25,
    scope: "nacional",
  },
  {
    id: "uol-cotidiano",
    name: "UOL Cotidiano",
    url: "https://noticias.uol.com.br/feed/cotidiano",
    enabled: false,
    weight: 0.25,
    scope: "nacional",
  },

  // ─── Rio de Janeiro / Pernambuco / São Paulo (DESATIVADOS) ───
  //
  // Sources foram adicionados em 2026-05-21 quando expandimos a Camada 2
  // pra outras capitais. Mas no MVP o app está focado em Salvador/RMS:
  // o cliente filtra `state == 'Bahia'` server-side, então relatos
  // dessas capitais entravam no Firestore e nunca apareciam pra usuário.
  // Pior: pra usuário com cliente antigo (pré-filtro), apareciam
  // misturados na lista. Desligamos a ingestão por enquanto pra evitar
  // ruído operacional. Reativar quando o app ganhar selector de estado
  // na UI. Reference completa preservada pra retomada sem perda.
  {
    id: "gnews-tiroteio-rio",
    name: "Google News · tiroteio Rio de Janeiro",
    url: GOOGLE_NEWS_RSS("tiroteio \"Rio de Janeiro\""),
    enabled: false,
    weight: 0.30,
    scope: "rio_de_janeiro",
  },
  {
    id: "gnews-operacao-rio",
    name: "Google News · operação policial Rio",
    url: GOOGLE_NEWS_RSS("operação policial \"Rio de Janeiro\""),
    enabled: false,
    weight: 0.30,
    scope: "rio_de_janeiro",
  },
  {
    id: "gnews-assalto-rio",
    name: "Google News · assalto Rio",
    url: GOOGLE_NEWS_RSS("assalto OR roubo \"Rio de Janeiro\""),
    enabled: false,
    weight: 0.30,
    scope: "rio_de_janeiro",
  },
  {
    id: "g1-rio",
    name: "G1 Rio",
    url: "https://g1.globo.com/rss/g1/rio-de-janeiro/",
    enabled: false,
    weight: 0.35,
    scope: "rio_de_janeiro",
  },
  {
    id: "gnews-tiroteio-recife",
    name: "Google News · tiroteio Recife",
    url: GOOGLE_NEWS_RSS("tiroteio Recife OR Pernambuco"),
    enabled: false,
    weight: 0.30,
    scope: "recife",
  },
  {
    id: "gnews-operacao-recife",
    name: "Google News · operação policial Recife",
    url: GOOGLE_NEWS_RSS("operação policial Recife OR Pernambuco"),
    enabled: false,
    weight: 0.30,
    scope: "recife",
  },
  {
    id: "gnews-assalto-recife",
    name: "Google News · assalto Recife",
    url: GOOGLE_NEWS_RSS("assalto OR roubo Recife OR \"Jaboatão\""),
    enabled: false,
    weight: 0.30,
    scope: "recife",
  },
  {
    id: "g1-pe",
    name: "G1 Pernambuco",
    url: "https://g1.globo.com/rss/g1/pe/pernambuco/",
    enabled: false,
    weight: 0.35,
    scope: "recife",
  },
  {
    id: "gnews-tiroteio-sp",
    name: "Google News · tiroteio São Paulo",
    url: GOOGLE_NEWS_RSS("tiroteio \"São Paulo\""),
    enabled: false,
    weight: 0.30,
    scope: "sao_paulo",
  },
  {
    id: "gnews-operacao-sp",
    name: "Google News · operação policial SP",
    url: GOOGLE_NEWS_RSS("operação policial \"São Paulo\""),
    enabled: false,
    weight: 0.30,
    scope: "sao_paulo",
  },
  {
    id: "gnews-assalto-sp",
    name: "Google News · assalto SP",
    url: GOOGLE_NEWS_RSS("assalto OR roubo \"São Paulo\""),
    enabled: false,
    weight: 0.30,
    scope: "sao_paulo",
  },
  {
    id: "g1-sp",
    name: "G1 São Paulo",
    url: "https://g1.globo.com/rss/g1/sao-paulo/",
    enabled: false,
    weight: 0.35,
    scope: "sao_paulo",
  },
];

module.exports = {
  SOURCES,
  enabledSources: () => SOURCES.filter((s) => s.enabled),
};
