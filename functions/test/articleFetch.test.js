"use strict";

const { test } = require("node:test");
const assert = require("node:assert/strict");

const { fetchArticleText, _internal } = require("../lib/articleFetch");
const { extractReadableText, decodeEntities, isUnfetchableHost, MIN_USEFUL_CHARS } =
  _internal;

const longPara = (s) => s.repeat(Math.ceil((MIN_USEFUL_CHARS + 50) / s.length));

test("extractReadableText pega o texto dos parágrafos", () => {
  const body = longPara("O tiroteio ocorreu na Rua da Mangueira, em Pirajá. ");
  const html = `<html><body><nav>menu inicio contato</nav><p>${body}</p><footer>rodape</footer></body></html>`;
  const out = extractReadableText(html);
  assert.match(out, /Pirajá/);
  assert.doesNotMatch(out, /menu inicio/);
  assert.doesNotMatch(out, /rodape/);
});

test("extractReadableText remove script e style", () => {
  const body = longPara("Operação policial no bairro de São Caetano nesta terça. ");
  const html = `<p>${body}</p><script>var x = 'Liberdade roubo';</script><style>.a{color:red}</style>`;
  const out = extractReadableText(html);
  assert.match(out, /São Caetano/);
  assert.doesNotMatch(out, /var x/);
  assert.doesNotMatch(out, /color:red/);
});

test("extractReadableText cai pra raspar tudo quando não há <p> útil", () => {
  const body = longPara("Homicídio registrado no Subúrbio Ferroviário durante a madrugada. ");
  const html = `<div>${body}</div>`;
  const out = extractReadableText(html);
  assert.match(out, /Subúrbio Ferroviário/);
});

test("extractReadableText corta em maxChars sem quebrar palavra", () => {
  const body = longPara("palavra ");
  const html = `<p>${body}</p>`;
  const out = extractReadableText(html, 50);
  assert.ok(out.length <= 50);
  assert.doesNotMatch(out, /palavr$/); // não terminou no meio de "palavra"
});

test("extractReadableText tolera entrada vazia/inválida", () => {
  assert.equal(extractReadableText(""), "");
  assert.equal(extractReadableText(null), "");
  assert.equal(extractReadableText(undefined), "");
});

test("decodeEntities resolve nomeadas e numéricas", () => {
  assert.equal(decodeEntities("a&amp;b"), "a&b");
  assert.equal(decodeEntities("Pira&#106;&aacute;"), "Pirajá"); // &#106;=j, &aacute;=á
  assert.equal(decodeEntities("ca&#231;amba"), "caçamba"); // &#231; = ç
  assert.equal(decodeEntities("h&#xE9;lice"), "hélice"); // hex E9 = é
  assert.equal(decodeEntities("aspas&nbsp;duplas"), "aspas duplas"); // nbsp = espaço
});

test("decodeEntities troca entidade desconhecida por espaço (não deixa cru)", () => {
  assert.doesNotMatch(decodeEntities("x&naoexiste;y"), /&naoexiste;/);
});

test("isUnfetchableHost barra google news e URLs inválidas", () => {
  assert.equal(isUnfetchableHost("https://news.google.com/rss/articles/ABC"), true);
  assert.equal(isUnfetchableHost("https://www.google.com/x"), true);
  assert.equal(isUnfetchableHost("not a url"), true);
  assert.equal(isUnfetchableHost("https://g1.globo.com/ba/bahia/noticia/x.ghtml"), false);
  assert.equal(isUnfetchableHost("https://www.correio24horas.com.br/n/y"), false);
});

test("fetchArticleText devolve null pra host inelegível sem fazer rede", async () => {
  let called = false;
  const fetchImpl = async () => {
    called = true;
    return { ok: true, text: async () => "<p>x</p>" };
  };
  const out = await fetchArticleText("https://news.google.com/rss/articles/X", {
    fetchImpl,
  });
  assert.equal(out, null);
  assert.equal(called, false);
});

test("fetchArticleText extrai corpo de host elegível", async () => {
  const body = "O assalto aconteceu na Avenida San Martin, no bairro do Retiro, em Salvador. ".repeat(5);
  const fetchImpl = async () => ({
    ok: true,
    url: "https://g1.globo.com/ba/bahia/noticia/x.ghtml",
    headers: { get: () => "text/html; charset=utf-8" },
    text: async () => `<html><body><p>${body}</p></body></html>`,
  });
  const out = await fetchArticleText("https://g1.globo.com/ba/bahia/noticia/x.ghtml", {
    fetchImpl,
  });
  assert.match(out, /Retiro/);
});

test("fetchArticleText devolve null quando redirect termina em google", async () => {
  const fetchImpl = async () => ({
    ok: true,
    url: "https://consent.google.com/x",
    headers: { get: () => "text/html" },
    text: async () => "<p>consent page</p>",
  });
  const out = await fetchArticleText("https://example.com/x", { fetchImpl });
  assert.equal(out, null);
});

test("fetchArticleText devolve null em corpo curto demais", async () => {
  const fetchImpl = async () => ({
    ok: true,
    url: "https://g1.globo.com/x",
    headers: { get: () => "text/html" },
    text: async () => "<p>curto</p>",
  });
  const out = await fetchArticleText("https://g1.globo.com/x", { fetchImpl });
  assert.equal(out, null);
});

test("fetchArticleText nunca lança — erro de rede vira null", async () => {
  const fetchImpl = async () => {
    throw new Error("network down");
  };
  const out = await fetchArticleText("https://g1.globo.com/x", { fetchImpl });
  assert.equal(out, null);
});
