# TJ-BA via DataJud — investigação técnica

**Status:** investigação concluída. **Decisão: adiar implementação** —
DataJud não atende caso de uso do Faro como fonte de tempo quase-real.
Útil apenas pra **base histórica** ou validação acadêmica.

## O que é DataJud

API pública do CNJ (Conselho Nacional de Justiça) que expõe metadados
de processos de **todos os tribunais brasileiros**, incluindo TJ-BA.

- **Endpoint TJ-BA:** `https://api-publica.datajud.cnj.jus.br/api_publica_tjba/_search`
- **Auth:** header `Authorization: APIKey [chave-pública]` — chave
  rotacionada pelo CNJ periodicamente, distribuída na própria wiki
- **Linguagem de query:** Elasticsearch DSL (JSON no body POST)
- **Governança:** Resolução CNJ nº 160/2020
- **Doc:** https://datajud-wiki.cnj.jus.br/api-publica/

## Como filtrar

Body Elasticsearch típico (validado pela documentação):

```json
{
  "size": 50,
  "query": {
    "bool": {
      "must": [
        { "match": { "classe.codigo": 1716 } },
        { "range": { "dataAjuizamento": { "gte": "2025-01-01" } } }
      ]
    }
  },
  "sort": [{ "@timestamp": { "order": "desc" } }]
}
```

Campos principais retornados:
- `numeroProcesso`
- `classe.codigo` (TPU — Tabela Processual Unificada)
- `orgaoJulgador.nome` (varas: comarcas de Salvador, RMS, interior)
- `dataAjuizamento` / `@timestamp`
- `assuntos[]` (códigos de tipos: 14782 = roubo, 14797 = furto, etc.)

**Códigos relevantes pra Faro** (TPU):

| Código | Descrição |
|---|---|
| 14782 | Roubo (CP 157) |
| 14797 | Furto (CP 155) |
| 14794 | Lesão Corporal (CP 129) |
| 14781 | Latrocínio |
| 12544 | Tráfico de Drogas (Lei 11.343, art. 33) |
| 14820 | Receptação |

## Problemas que matam o caso de uso

### 1. Latência: 90 dias

A wiki explicita que cada tribunal envia snapshots ao CNJ a cada
**~90 dias** (Resolução 234/2016, art. 12). O dado mais recente que
você consegue pra TJ-BA é, na prática, de 1-3 meses atrás.

**Implicação direta no Faro:** o app é sobre o "agora" — janela de
filtro hoje vai de "Hoje" a "30 dias". Processos com 90+ dias de
latência caem fora de 100% das janelas.

### 2. Geolocalização ruim

`orgaoJulgador.nome` traz vara/comarca, não endereço do crime. Em
Salvador, isso significa "1ª Vara Criminal de Salvador" — sem
granularidade de bairro. Pra Faro virar útil precisaria parsear o
texto da denúncia (que não vem no DataJud).

### 3. Viés sistemático

Um processo na justiça reflete:
- Crime que **virou BO**
- BO que virou **inquérito**
- Inquérito que virou **denúncia**

Cada etapa filtra. Em Salvador, sub-notificação de roubos comuns é
brutal — só vira processo o que tem investigação ativa ou flagrante.
**Pequenas ocorrências (assalto a pedestre, celular) somem.**

## O que SERIA útil

Se o Faro evoluísse pra ter:
1. **Camada histórica** (3-12 meses atrás) pra análise de tendência
2. **Modo "pesquisa"** pra acadêmicos (já documentado em
   `02_plataforma_academica.md`)
3. **Visualização agregada por comarca** sem prometer tempo real

…aí DataJud encaixa. Hoje não encaixa.

## Decisão

**Não implementar ingest agora.** Tempo investido seria melhor gasto em:
- Acompanhar pedido LAI à SSP-BA (fonte com latência real menor)
- Sindicato dos Rodoviários (relato direto, em tempo real)

**Revisitar quando:**
- A plataforma acadêmica do Faro estiver no ar (DataJud + Faro vira
  insumo natural pra pesquisadores)
- A janela de visualização do app permitir "histórico" (6m+) como
  modo explícito
- Surgir caso de uso específico tipo "padrões judiciais por bairro"

## Stub guardado pra futuro

Esqueleto técnico pronto pra ativar quando decisão mudar — deixo
documentado aqui pra não perder o caminho:

```js
// functions/lib/tjBaIngest.js (NÃO IMPLEMENTAR HOJE)
const ENDPOINT = "https://api-publica.datajud.cnj.jus.br/api_publica_tjba/_search";
const RELEVANT_CLASSES = [14782, 14797, 14794, 14781, 12544, 14820];

async function fetchProcessos(classeId, since) {
  return fetch(ENDPOINT, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Authorization": `APIKey ${process.env.DATAJUD_KEY}`,
    },
    body: JSON.stringify({
      size: 100,
      query: {
        bool: {
          must: [
            { match: { "classe.codigo": classeId } },
            { range: { dataAjuizamento: { gte: since } } },
          ],
        },
      },
    }),
  });
}
```

Quando ativar, considerar:
- `source: 'tjba_datajud'` com **peso editorial 0.45** (fonte estatal
  forte, mas latência alta)
- Marker visual diferenciado no mapa (pin neutro, sem cor de risco —
  é histórico, não evento)
- Disclaimer fixo nos cards: "Processo judicial. Crime ocorreu
  há semanas/meses atrás."
