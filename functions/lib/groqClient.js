"use strict";

/**
 * Cliente Groq — ATIVO.
 *
 * Por que Groq (e não Gemini, que tentamos antes):
 * - Gemini free tier limita a 250 req/DIA em 2.5 Flash. Não cobre 2.4k/dia
 *   do Faro. Tentativa documentada em geminiClient.js.
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

Recebe título + descrição de uma notícia. Retorna APENAS JSON com:
{
  "security_related": true|false,   // é sobre violência urbana real, não política/economia/esporte?
  "occurrence_type": "tiroteio"|"homicidio"|"roubo"|"acao_policial"|"sequestro"|"agressao"|"outros"|null,
  "neighborhood": "nome do bairro de Salvador mencionado",  // ou null se não há
  "city": "Salvador",   // ou outra cidade BA, ou null
  "confidence": 0.0-1.0  // sua confiança na extração
}

Regras:
- Bairros: use o nome exato como mencionado, sem cidade ("Pirajá" não "Pirajá, Salvador")
- Se a notícia menciona só município sem bairro, neighborhood=null
- Notícias políticas, comentários, opiniões → security_related=false
- Notícias de outras cidades fora da Bahia → security_related=true mas city=outra
- Sem campo extra, sem markdown, sem explicação. Apenas o JSON.`;

async function classify(title, description) {
  return classifyWithRetry(title, description, 3);
}

async function classifyWithRetry(title, description, maxRetries) {
  for (let attempt = 0; attempt <= maxRetries; attempt++) {
    try {
      return await doClassify(title, description);
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

async function doClassify(title, description) {
  const key = process.env.GROQ_API_KEY;
  if (!key) {
    throw new Error("GROQ_API_KEY não configurada");
  }

  const userPrompt = `Título: ${title}\n\nDescrição: ${description || "(sem descrição)"}`;

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
