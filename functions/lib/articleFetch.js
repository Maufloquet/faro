"use strict";

/**
 * Busca o corpo da matéria pra o classificador ter mais que título + resumo.
 *
 * Por que existe: o RSS entrega só título e um resumo curto. O bairro onde
 * o fato aconteceu quase sempre está no corpo do texto ("o crime ocorreu na
 * Rua X, no bairro de Pirajá"), não no resumo. Sem o corpo, o classificador
 * ou não acha bairro (e a ocorrência cai no centróide da cidade, empilhando
 * tudo no centro) ou pega um bairro secundário citado de passagem (a origem
 * da vítima, uma referência). Resultado: ocorrência no bairro errado.
 *
 * Limite consciente: links do Google News (news.google.com/rss/articles/...)
 * são redirecionadores ofuscados — não dá pra extrair o artigo direto deles.
 * Pra esses, devolvemos null e o pipeline segue só com título + resumo (sem
 * regressão). Os 6 portais com RSS direto (G1 BA, Correio, A Tarde, iBahia,
 * BNews, Bahia no Ar) entregam a URL real e é onde o ganho acontece.
 */

const FETCH_TIMEOUT_MS = 8000;
const MAX_CHARS = 5000;
const MIN_USEFUL_CHARS = 200;

/**
 * Hosts que não servem o artigo direto. Buscar neles devolve página de
 * redirecionamento/consentimento, não a matéria — texto inútil ou enganoso.
 */
function isUnfetchableHost(url) {
  try {
    const host = new URL(url).hostname.toLowerCase();
    return host.endsWith("google.com") || host.endsWith("googleusercontent.com");
  } catch (_) {
    return true; // URL inválida: não tem o que buscar
  }
}

/**
 * Busca a URL e devolve o texto legível do corpo, ou null se não der
 * (host inelegível, timeout, erro de rede, HTML pobre demais). Nunca lança —
 * o caller trata null como "siga só com título + resumo".
 *
 * @param {string} url
 * @param {{timeoutMs?: number, maxChars?: number, fetchImpl?: Function}} opts
 * @returns {Promise<string|null>}
 */
async function fetchArticleText(url, opts = {}) {
  if (!url || isUnfetchableHost(url)) return null;
  const timeoutMs = opts.timeoutMs ?? FETCH_TIMEOUT_MS;
  const maxChars = opts.maxChars ?? MAX_CHARS;
  const doFetch = opts.fetchImpl || fetch;

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const r = await doFetch(url, {
      redirect: "follow",
      signal: controller.signal,
      headers: {
        "User-Agent":
          "Mozilla/5.0 (compatible; FaroBot/0.1; +https://github.com/Maufloquet/faro)",
        Accept: "text/html,application/xhtml+xml",
      },
    });
    if (!r.ok) return null;
    // Se o redirect terminou num host inelegível (Google News mandou pra
    // página de consentimento), descarta — o texto não seria do artigo.
    if (r.url && isUnfetchableHost(r.url)) return null;
    const ctype = (r.headers.get("content-type") || "").toLowerCase();
    if (ctype && !ctype.includes("html")) return null;

    const html = await r.text();
    const text = extractReadableText(html, maxChars);
    return text && text.length >= MIN_USEFUL_CHARS ? text : null;
  } catch (_) {
    return null;
  } finally {
    clearTimeout(timer);
  }
}

/**
 * Extrai o texto legível de um HTML. Heurística sem dependência:
 *   1. Remove script/style/noscript/svg/head e comentários.
 *   2. Junta o texto dos parágrafos (<p>) — é onde mora o corpo da matéria;
 *      menus, rodapés e navegação raramente vêm em <p>.
 *   3. Se sobrar pouco texto em <p> (página atípica), cai pra remover todas
 *      as tags do HTML limpo.
 *   4. Decodifica entidades, colapsa espaços, corta em maxChars.
 *
 * Pura e testável.
 *
 * @param {string} html
 * @param {number} maxChars
 * @returns {string}
 */
function extractReadableText(html, maxChars = MAX_CHARS) {
  if (!html || typeof html !== "string") return "";

  // 1) Tira blocos que nunca são corpo de texto.
  let cleaned = html
    .replace(/<!--[\s\S]*?-->/g, " ")
    .replace(/<(script|style|noscript|svg|head|nav|footer|aside|form)\b[\s\S]*?<\/\1>/gi, " ");

  // 2) Texto dos parágrafos.
  const paras = [];
  const pRegex = /<p\b[^>]*>([\s\S]*?)<\/p>/gi;
  let m;
  while ((m = pRegex.exec(cleaned)) !== null) {
    const t = collapse(decodeEntities(stripTags(m[1])));
    if (t.length > 0) paras.push(t);
  }
  let text = paras.join(" ");

  // 3) Fallback: <p> rendeu pouco, raspa tudo.
  if (text.length < MIN_USEFUL_CHARS) {
    text = collapse(decodeEntities(stripTags(cleaned)));
  }

  // 4) Corta no limite, sem partir palavra no meio quando dá.
  if (text.length > maxChars) {
    const cut = text.slice(0, maxChars);
    const lastSpace = cut.lastIndexOf(" ");
    text = lastSpace > maxChars * 0.8 ? cut.slice(0, lastSpace) : cut;
  }
  return text.trim();
}

function stripTags(s) {
  return s.replace(/<[^>]+>/g, " ");
}

function collapse(s) {
  return s.replace(/\s+/g, " ").trim();
}

const NAMED_ENTITIES = {
  amp: "&",
  lt: "<",
  gt: ">",
  quot: '"',
  apos: "'",
  nbsp: " ",
  ndash: "–",
  mdash: "—",
  hellip: "…",
  laquo: "«",
  raquo: "»",
  ldquo: "“",
  rdquo: "”",
  lsquo: "‘",
  rsquo: "’",
  aacute: "á",
  eacute: "é",
  iacute: "í",
  oacute: "ó",
  uacute: "ú",
  atilde: "ã",
  otilde: "õ",
  acirc: "â",
  ecirc: "ê",
  ocirc: "ô",
  ccedil: "ç",
  agrave: "à",
};

/**
 * Decodifica entidades HTML — numéricas (&#233; / &#xE9;) e as nomeadas
 * comuns em português. O resto vira espaço pra não deixar "&xyz;" cru.
 */
function decodeEntities(s) {
  if (!s) return "";
  return s.replace(/&(#x?[0-9a-f]+|[a-z]+);/gi, (whole, body) => {
    if (body[0] === "#") {
      const code =
        body[1] === "x" || body[1] === "X"
          ? parseInt(body.slice(2), 16)
          : parseInt(body.slice(1), 10);
      if (Number.isFinite(code) && code > 0) {
        try {
          return String.fromCodePoint(code);
        } catch (_) {
          return " ";
        }
      }
      return " ";
    }
    const named = NAMED_ENTITIES[body.toLowerCase()];
    return named !== undefined ? named : " ";
  });
}

module.exports = { fetchArticleText };
module.exports._internal = {
  extractReadableText,
  decodeEntities,
  isUnfetchableHost,
  stripTags,
  collapse,
  MAX_CHARS,
  MIN_USEFUL_CHARS,
};
