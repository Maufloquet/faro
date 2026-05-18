# ADR-003 — Fogo Cruzado como fonte primária

**Data:** 2026-05-10 (consolidando Validação 0 concluída em 2026-05-10)
**Status:** Aceito

## Contexto

O Faro precisa de uma fonte de dados sólida pra existir antes de UGC
acumular. As opções de fonte oficial pública pra Salvador/Bahia:

1. **SSP-BA** — dados oficiais, mas só via portal Transparência Bahia
   (painel HTML, sem API, sem real-time). Latência de publicação alta.
2. **Fogo Cruzado** — instituto independente, API estruturada, real-time,
   cobertura BA + PE + RJ, licença CC-BY.
3. **Polícia Civil / Disque-Denúncia** — não público.
4. **Crowdsourcing puro** — chicken-and-egg na Fase 1.

## Alternativas consideradas

1. **SSP-BA como primário** — fonte oficial pesa mais editorialmente.
   Mas latência (horas a dias) destrói o valor "o que está acontecendo
   AGORA". Sem API estruturada, custaria scraping frágil.
2. **Fogo Cruzado como primário, SSP como complemento** — Fogo Cruzado
   é real-time e API-first; SSP-BA fica como auditoria histórica.
3. **Multi-fonte com peso editorial** — usar todas com pesos no score.

## Decisão

**Fogo Cruzado como fonte primária do MVP.** SSP foi rebaixado de
crítico durante a Validação 0 (concluída 2026-05-10): cobertura do Fogo
Cruzado em Salvador foi confirmada como suficiente pro piloto.

- Camada 1 (Fogo Cruzado): peso 1.0
- Camada 2 (mídia via Groq classification): peso 0.3
- Camada 5 (SSP estadual): peso 0.5 — auditoria caso a caso, não no MVP
- Outras camadas (3, 6, 7) entram em fases posteriores

## Consequências

**Positivas:**
- Validação 0 já cumpriu o gate: Fogo Cruzado cobre Salvador.
- API estável, latência baixa, dados estruturados.
- Sem custo de scraping frágil.

**Negativas:**
- Dependência de uma fonte externa: se Fogo Cruzado cai ou muda termos,
  o app fica sem dados primários. Mitigação: camada de cache + ingestão
  de notícias (Camada 2) como fallback parcial.
- Cobertura geográfica limitada a BA + PE + RJ. Expansão pra outros
  estados exigirá fontes alternativas.

## Revisão

Reavaliar se:
- Fogo Cruzado mudar política de acesso
- Expansão pra estado não coberto
- SSP-BA publicar API real-time
