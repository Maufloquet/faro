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

  // ─── RSS diretos quebrados (mantidos como referência, desativados) ───
  // bocao-news: domínio redirecionou pra bnews.com.br (Bocão virou BNews
  //   em algum momento). Home retorna 403 (anti-bot). RSS desconhecido.
  // bahia-noticias: /principal-rss aponta pra página HTML, não pro XML.
  // Estratégia: pegamos cobertura desses portais via gnews-* abaixo.
  {
    id: "bocao-news",
    name: "Bocão News (BNews)",
    url: "https://www.bnews.com.br/feed",
    enabled: false,
    weight: 0.30,
    scope: "salvador",
  },
  {
    id: "bahia-noticias",
    name: "Bahia Notícias",
    url: "https://www.bahianoticias.com.br/principal-rss",
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
];

module.exports = {
  SOURCES,
  enabledSources: () => SOURCES.filter((s) => s.enabled),
};
