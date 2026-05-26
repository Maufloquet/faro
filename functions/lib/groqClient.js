"use strict";

/**
 * Cliente Groq — ATIVO.
 *
 * Por que Groq (e não Gemini, que tentamos antes):
 * - Gemini free tier limita a 250 req/DIA em 2.5 Flash. Não cobre 2.4k/dia
 *   do Faro. Cliente da tentativa foi removido em 2026-05-22.
 * - Groq free tier: 14.4k req/dia + 30 req/min — folga real.
 * - Latência baixa (~500ms) ajuda quando rodando 100+ classificações em
 *   sequência dentro do timeout de 5min da Cloud Function.
 *
 * Pra trocar pra Gemini quando passar pra plano pago: trocar o require
 * em newsIngest.js e o secret. Cliente continua disponível.
 */

const GROQ_URL = "https://api.groq.com/openai/v1/chat/completions";
// 8B é suficiente pra extração estruturada de bairro + tipo. Free tier
// dá 30k TPM (vs 12k do 70B) — ~2.5x mais throughput, suficiente pro
// nosso volume sem estourar o limite por minuto.
const MODEL = "llama-3.1-8b-instant";

const SYSTEM_PROMPT = `Você é um classificador editorial de notícias de segurança urbana brasileiras.

Cobrimos Salvador e a Região Metropolitana de Salvador (Camaçari, Lauro de Freitas, Simões Filho).

Recebe título + descrição + (quando disponível) o corpo da matéria. Retorna APENAS JSON com:
{
  "security_related": true|false,   // é sobre violência urbana real, não política/economia/esporte?
  "occurrence_type": "tiroteio"|"homicidio"|"roubo"|"acao_policial"|"sequestro"|"agressao"|"outros"|null,
  "neighborhood": "nome do bairro onde o fato ocorreu",  // ou null
  "city": "Salvador"|"Camaçari"|"Lauro de Freitas"|"Simões Filho"|null,  // só essas 4 ou null se outra
  "bus_lines": ["1234", "Cajazeiras-Lapa"],   // ver regras detalhadas abaixo, ou []
  "transport_context": "onibus"|"metro"|null,  // só preencha se a notícia for explicitamente sobre transporte público
  "confidence": 0.0-1.0  // sua confiança na extração
}

Regras:
- O bairro é o LOCAL ONDE O FATO ACONTECEU. Leia o corpo inteiro pra achá-lo.
- Quando vários bairros são citados, escolha o do acontecimento — NÃO o bairro de
  residência da vítima/suspeito ("morador da Liberdade"), NÃO o destino de uma fuga
  ("fugiu sentido Cajazeiras"), NÃO uma referência de contexto. Esses são bairros
  errados; ignore-os.
- Se o texto dá só uma rua/avenida ou ponto de referência, infira o bairro a que
  pertence apenas se tiver certeza; senão neighborhood=null.
- Bairros: use o nome exato como mencionado, sem cidade ("Pirajá" não "Pirajá, Salvador")
- Se a notícia menciona só município sem bairro, neighborhood=null
- Se nenhum bairro do local do fato é claro, neighborhood=null (melhor null que errado)
- Se cidade é outra (Feira de Santana, Ilhéus, etc), retorne city=null
- bus_lines: extraia APENAS nesses 2 formatos quando o texto identifica claramente a linha:
    (a) número/código: "linha 1234" → "1234", "ônibus 0220-01" → "0220-01", "L-105" → "L-105"
    (b) origem-destino: "ônibus da linha Cajazeiras-Lapa" → "Cajazeiras-Lapa", "Pituba/Rodoviária" → "Pituba/Rodoviária"
  Exemplos de NÃO extrair (deixar []):
    - "ônibus rumo a Cajazeiras" (sem identificação da linha — só destino narrativo)
    - "ônibus na Avenida Paralela" (referência geográfica, não linha)
    - "linha de ônibus" (sem código nem par origem-destino)
    - "ônibus" / "coletivo" (genérico)
  Máx 40 caracteres por entrada. Se não há identificação clara, retorne [].
- transport_context: só preencha quando o crime aconteceu DENTRO ou no PONTO de transporte público. Crime na rua que por acaso menciona ônibus passando = null.
- Notícias políticas, comentários, opiniões, esporte → security_related=false
- Sem campo extra, sem markdown, sem explicação. Apenas o JSON.`;

async function classify(title, description, body = "") {
  return classifyWithRetry(title, description, body, 3);
}

async function classifyWithRetry(title, description, body, maxRetries) {
  for (let attempt = 0; attempt <= maxRetries; attempt++) {
    try {
      return await doClassify(title, description, body);
    } catch (e) {
      const m = e.message || "";
      const retry = parseRetryAfter(m);
      if (m.includes("Groq 429") && retry && attempt < maxRetries) {
        await sleep(retry + 150);
        continue;
      }
      throw e;
    }
  }
}

function parseRetryAfter(msg) {
  // Mensagens do Groq tipo: "Please try again in 1.079999999s"
  // ou "...in 235ms"
  const sec = msg.match(/try again in ([\d.]+)\s*s\b/i);
  if (sec) return Math.ceil(parseFloat(sec[1]) * 1000);
  const ms = msg.match(/try again in ([\d.]+)\s*ms\b/i);
  if (ms) return Math.ceil(parseFloat(ms[1]));
  return null;
}

function sleep(ms) {
  return new Promise((r) => setTimeout(r, ms));
}

async function doClassify(title, description, body = "") {
  const key = process.env.GROQ_API_KEY;
  if (!key) {
    throw new Error("GROQ_API_KEY não configurada");
  }

  const userPrompt = buildUserPrompt(title, description, body);

  const r = await fetch(GROQ_URL, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${key}`,
    },
    body: JSON.stringify({
      model: MODEL,
      messages: [
        { role: "system", content: SYSTEM_PROMPT },
        { role: "user", content: userPrompt },
      ],
      temperature: 0.1,
      response_format: { type: "json_object" },
      max_tokens: 200,
    }),
  });

  if (!r.ok) {
    const body = await r.text();
    throw new Error(`Groq ${r.status}: ${body.slice(0, 300)}`);
  }

  const data = await r.json();
  const content = data.choices?.[0]?.message?.content;
  if (!content) throw new Error("Groq retornou resposta vazia");

  // Defesa contra modelos que ignoram response_format e prefixam
  // a saída ("Here is the JSON: {...}", "```json {...} ```").
  const cleaned = extractJsonBlock(content);

  try {
    return JSON.parse(cleaned);
  } catch (e) {
    throw new Error(`Groq retornou JSON inválido: ${content.slice(0, 200)}`);
  }
}

/** Teto do corpo no prompt. Mantido enxuto de propósito: notícia de crime
 * põe o bairro nos primeiros parágrafos (a lide), então 2000 chars (~350
 * palavras) já cobrem o local do fato. Mandar o artigo inteiro estourava o
 * orçamento diário de tokens do Groq (TPD 500k no free tier) e prejudicava
 * a ingestão. 2000 dá o ganho de geocoding com ~3x menos tokens por chamada. */
const MAX_BODY_CHARS = 2000;

/**
 * Monta o prompt do usuário. O corpo entra como bloco separado e rotulado
 * pra o modelo distinguir o texto completo do resumo curto. Sem corpo
 * (item do Google News, fetch falhou), cai pro formato antigo título+resumo.
 */
function buildUserPrompt(title, description, body) {
  const lines = [
    `Título: ${title}`,
    "",
    `Descrição: ${description || "(sem descrição)"}`,
  ];
  const trimmed = (body || "").trim();
  if (trimmed.length > 0) {
    const clipped =
      trimmed.length > MAX_BODY_CHARS ? trimmed.slice(0, MAX_BODY_CHARS) : trimmed;
    lines.push("", `Corpo da matéria: ${clipped}`);
  }
  return lines.join("\n");
}

/**
 * Extrai o primeiro bloco JSON de uma string que pode ter prefixos
 * ("Here is the JSON: {...}"), markdown ("```json {...} ```") ou ruído.
 */
function extractJsonBlock(s) {
  const fenced = s.match(/```(?:json)?\s*([\s\S]*?)```/);
  if (fenced) return fenced[1].trim();

  const start = s.indexOf("{");
  const end = s.lastIndexOf("}");
  if (start !== -1 && end > start) return s.slice(start, end + 1);

  return s.trim();
}

module.exports = { classify };
module.exports._internal = { extractJsonBlock, parseRetryAfter, buildUserPrompt, MAX_BODY_CHARS };
