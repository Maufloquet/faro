"use strict";

const { describe, it } = require("node:test");
const assert = require("node:assert/strict");

const { _internal } = require("../lib/groqClient");
const { extractJsonBlock, parseRetryAfter, isDailyTokenLimit } = _internal;

describe("groqClient.isDailyTokenLimit", () => {
  it("detecta limite diário (TPD / per day)", () => {
    const msg = 'Groq 429: tokens per day (TPD): Limit 500000, Used 499882';
    assert.equal(isDailyTokenLimit(msg), true);
  });
  it("não confunde com limite por minuto (TPM)", () => {
    const msg = 'Groq 429: tokens per minute (TPM): Limit 30000';
    assert.equal(isDailyTokenLimit(msg), false);
  });
});

describe("groqClient.extractJsonBlock", () => {
  it("retorna JSON puro intacto", () => {
    const input = '{"a":1,"b":"x"}';
    assert.equal(extractJsonBlock(input), input);
  });

  it("descarta prefixo textual antes do JSON", () => {
    const input = 'Here is the JSON: {"security_related":true}';
    assert.equal(extractJsonBlock(input), '{"security_related":true}');
  });

  it("descarta fences markdown ```json ... ```", () => {
    const input = '```json\n{"a":1}\n```';
    assert.equal(extractJsonBlock(input).trim(), '{"a":1}');
  });

  it("descarta fences markdown sem identificação de linguagem", () => {
    const input = '```\n{"a":1}\n```';
    assert.equal(extractJsonBlock(input).trim(), '{"a":1}');
  });

  it("preserva o JSON externo quando há aninhado", () => {
    const input = 'Output: {"outer":{"inner":1}} done';
    assert.equal(extractJsonBlock(input), '{"outer":{"inner":1}}');
  });

  it("retorna a string original (trim) quando não há JSON detectável", () => {
    assert.equal(extractJsonBlock("   hello world   "), "hello world");
  });
});

describe("groqClient.parseRetryAfter", () => {
  it("extrai segundos do formato 'try again in Xs'", () => {
    assert.equal(parseRetryAfter("Please try again in 1.5s"), 1500);
  });

  it("extrai milissegundos do formato 'try again in Xms'", () => {
    assert.equal(parseRetryAfter("try again in 235ms"), 235);
  });

  it("arredonda pra cima ao converter segundos pra ms", () => {
    assert.equal(parseRetryAfter("try again in 1.079999999s"), 1080);
  });

  it("retorna null quando não há marcador reconhecível", () => {
    assert.equal(parseRetryAfter("Some other error"), null);
    assert.equal(parseRetryAfter(""), null);
  });

  it("case-insensitive no marcador", () => {
    assert.equal(parseRetryAfter("TRY AGAIN IN 2s"), 2000);
  });
});
