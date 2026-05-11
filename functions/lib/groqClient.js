"use strict";

/**
 * Cliente Groq — mantido como FALLBACK.
 *
 * Cliente ativo hoje é o geminiClient.js (Gemini Flash 2.5). Razões da
 * troca documentadas no header daquele arquivo.
 *
 * Pra reativar este: substitua o require em newsIngest.js de volta pra
 * "./groqClient" e troque o secret GEMINI_API_KEY → GROQ_API_KEY.
 *
 * @deprecated em favor de geminiClient.js
 */

const GROQ_URL = "https://api.groq.com/openai/v1/chat/completions";
const MODEL = "llama-3.3-70b-versatile";

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

  try {
    return JSON.parse(content);
  } catch (e) {
    throw new Error(`Groq retornou JSON inválido: ${content.slice(0, 200)}`);
  }
}

module.exports = { classify };
