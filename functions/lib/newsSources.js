"use strict";

/**
 * Fontes de notícias monitoradas pela função ingestNewsBahia.
 *
 * Cada fonte tem peso editorial:
 * - 0.35: portal local consolidado com cobertura ampla
 * - 0.30: portal local ou Google News por query (agregador)
 * - 0.25: portal estado/nacional (menor relevância pra Salvador específico)
 *
 * Pra ATIVAR ou DESATIVAR uma fonte, mude o campo `enabled`.
 * Pra adicionar uma nova: copie um item, ajuste URL e id.
 *
 * Notas:
 * - Google News RSS por query é o mais estável (não depende de HTML
 *   próprio do portal). Bom como rede de segurança quando um RSS oficial
 *   muda silenciosamente.
 * - Quando uma fonte retorna erro 2 sincs seguidos, vai pra log e pode
 *   ser desativada manualmente até checar.
 */

const GOOGLE_NEWS_RSS = (query) =>
  `https://news.google.com/rss/search?q=${encodeURIComponent(query)}&hl=pt-BR&gl=BR&ceid=BR:pt-419`;

const SOURCES = [
  // ─── Portais locais Bahia (cobertura direta de Salvador e RMS) ───
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
    url: "https://www.correio24horas.com.br/feed",
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
  {
    id: "bahia-noticias",
    name: "Bahia Notícias",
    url: "https://www.bahianoticias.com.br/rss/feed",
    enabled: true,
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

  // ─── Google News (rede de segurança — pega o que os portais perdem) ───
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
    url: GOOGLE_NEWS_RSS("assalto Salvador BA"),
    enabled: false,
    weight: 0.30,
    scope: "salvador",
  },

  // ─── Nacionais (úteis quando incidente vira pauta nacional) ───
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
  /** Helper pra debug/log — só as ativas. */
  enabledSources: () => SOURCES.filter((s) => s.enabled),
};
