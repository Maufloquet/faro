"use strict";

/**
 * Cliente Gemini Flash 2.5 para classificação editorial de notícias.
 *
 * Escolhido em vez de Groq por:
 * - Custo absoluto menor (~$0.075/1M input vs Groq $0.59/1M)
 * - PT-BR ligeiramente superior (caso a caso em nomes de bairro)
 * - Já no stack GCP — sem provedor adicional
 * - Free tier 1.5k req/dia cobre nosso volume (~2.4k/dia, mas pico
 *   diário cabe; quando estourar é centavos)
 *
 * Single-shot via REST API — sem SDK adicional, sem deps.
 */

const MODEL = "gemini-2.5-flash";
const ENDPOINT = `https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent`;

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
  const key = process.env.GEMINI_API_KEY;
  if (!key) {
    throw new Error("GEMINI_API_KEY não configurada");
  }

  const userText = `Título: ${title}\n\nDescrição: ${description || "(sem descrição)"}`;

  const r = await fetch(`${ENDPOINT}?key=${encodeURIComponent(key)}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      systemInstruction: { parts: [{ text: SYSTEM_PROMPT }] },
      contents: [{ role: "user", parts: [{ text: userText }] }],
      generationConfig: {
        temperature: 0.1,
        responseMimeType: "application/json",
        maxOutputTokens: 200,
      },
    }),
  });

  if (!r.ok) {
    const body = await r.text();
    throw new Error(`Gemini ${r.status}: ${body.slice(0, 300)}`);
  }

  const data = await r.json();
  const content = data.candidates?.[0]?.content?.parts?.[0]?.text;
  if (!content) {
    throw new Error(`Gemini retornou resposta vazia: ${JSON.stringify(data).slice(0, 300)}`);
  }

  const cleaned = extractJsonBlock(content);
  try {
    return JSON.parse(cleaned);
  } catch (e) {
    throw new Error(`Gemini retornou JSON inválido: ${content.slice(0, 200)}`);
  }
}

function extractJsonBlock(s) {
  const fenced = s.match(/```(?:json)?\s*([\s\S]*?)```/);
  if (fenced) return fenced[1].trim();
  const start = s.indexOf("{");
  const end = s.lastIndexOf("}");
  if (start !== -1 && end > start) return s.slice(start, end + 1);
  return s.trim();
}

module.exports = { classify };
