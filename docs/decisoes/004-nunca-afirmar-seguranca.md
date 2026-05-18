# ADR-004 — Princípio editorial: nunca afirmar segurança

**Data:** 2026-05-10
**Status:** Aceito · Hard rule

## Contexto

A pergunta natural do usuário é "essa área é segura?". A resposta
honesta é: nenhum app, dado ou algoritmo pode garantir segurança. Áreas
sem relatos podem ser perigosas (subnotificação, ausência de fontes).
Áreas com muitos relatos podem estar momentaneamente calmas.

Afirmar segurança gera:

1. **Risco legal:** responsabilidade civil se acontecer algo numa área
   que o app marcou como "segura".
2. **Risco editorial:** reforço de viés territorial — periferias
   tipicamente têm menos cobertura de fontes oficiais e menos UGC, logo
   apareceriam como "seguras" por falsa ausência. Discriminação
   territorial é ilegal (Lei de Mobilidade Urbana) e antiética.
3. **Risco de produto:** primeira falha vira manchete e mata confiança.

## Alternativas consideradas

1. **Score numérico com label "Segura / Atenção / Perigosa"** — comum em
   apps similares, vetado pelos riscos acima.
2. **Heatmap binário (área quente / área fria)** — implícito demais,
   o usuário lê "fria = segura".
3. **Comunicação probabilística + linguagem de fato** — "X relatos
   nas últimas 24h", "ausência de relatos não significa ausência de
   ocorrências". Honesto e defensável.

## Decisão

**O Faro NUNCA usa as palavras "seguro", "seguro", "perigoso", "perigosa"
nem similares sobre uma localização.** Hard rule editorial.

Comunicação permitida:
- "X relatos confirmados em Y" (fato bruto)
- "Última atividade há N horas" (fato bruto)
- "Densidade Z relatos por 10k habitantes" (normalização explícita)
- "Ausência de relatos não implica ausência de ocorrências" (ressalva
  obrigatória em rodapés de heatmap)

Comunicação proibida:
- "Área segura / perigosa"
- "Evite essa rota"
- Veredito ou recomendação direta
- Cores que culturalmente significam julgamento (vermelho-como-veredito
  vs. vermelho-como-densidade — usar palette de calor com legenda)

Copy de FCM e in-app reforça o tom (testado unitariamente em
`functions/test/proximityAlert.test.js` — palavras como 'PERIGO',
'ALERTA', 'EVITE' são proibidas nos textos).

## Consequências

**Positivas:**
- Defensável legalmente.
- Não reforça viés territorial.
- Cria diferencial editorial vs. concorrentes que dão veredito.

**Negativas:**
- Menos "viralizável" — vereditos ganham mais cliques.
- Exige educação do usuário sobre como ler densidade vs. veredito.
- UX precisa ser melhor pra compensar (mapa rico, contexto, histórico).

## Revisão

**Não negociável** no escopo previsto. Mudança requer ADR novo e
parecer jurídico.
