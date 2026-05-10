# Findings — Validação 2 (Fogo Cruzado)

**Data:** 2026-05-10
**Status: APROVADA com folga**

## Resumo executivo

A API do Fogo Cruzado é totalmente funcional, cobre 4 estados (BA, PA, PE, RJ) e entrega 100% dos registros com geocoordenadas válidas. Salvador é a cidade dominante no estado da Bahia, com volume mais que suficiente para popular o mapa do MVP.

## Resultado por estado (amostra das 100 ocorrências mais recentes)

| Estado | Com lat/lng | Janela temporal | Cidade dominante |
|---|---|---|---|
| **Bahia** | 100/100 | 2026-04-14 → 2026-05-09 | **Salvador** (78%) |
| Pará | 100/100 | 2026-02-15 → 2026-05-08 | Belém (49%) |
| Pernambuco | 100/100 | 2026-04-06 → 2026-05-08 | Recife (33%) |
| Rio de Janeiro | 100/100 | 2026-04-24 → 2026-05-09 | Rio de Janeiro (61%) |

## Salvador — análise específica

- 78 de 100 ocorrências mais recentes na Bahia são em Salvador
- Janela: 14 de abril a 9 de maio de 2026 (~26 dias)
- **Densidade: aproximadamente 3 ocorrências/dia em Salvador**
- Cidades secundárias na RMS aparecem (Camaçari 7, Lauro de Freitas 4, Mata de São João 3, Simões Filho 2) — útil para ampliação futura

## Comparativo de densidade entre piloto-candidatas

| Cidade | Ocorrências/dia (estimativa) | Sentimento |
|---|---|---|
| Rio de Janeiro | ~3,8 | Alta densidade, mercado mais saturado |
| **Salvador** | **~3,0** | **Alta densidade, sem concorrência direta** |
| Recife | ~1,1 | Densidade moderada |
| Belém | ~0,5 | Densidade baixa |

Salvador tem densidade comparável ao RJ, com a vantagem de não ter concorrentes diretos estabelecidos e ser a cidade do autor.

## Qualidade dos dados

- **100% com geocoordenadas** — não precisa de Geocoding adicional para esta camada
- Granularidade de bairro presente em todos os registros (campo `neighborhood.name`)
- Atualização em tempo real (último registro com poucas horas de delay)

## Implicações para o projeto

1. **Validação 2 oficialmente APROVADA**
2. **Validação 1 (SSP-BA) deixa de ser crítica** — vira camada complementar opcional. Pode ser feita em paralelo ou após o MVP.
3. **Salvador é o piloto recomendado**, com Rio de Janeiro como alternativa.
4. A camada base do mapa do MVP pode ser construída só com Fogo Cruzado.
5. O custo de Geocoding (Validação 3) cai significativamente — boa parte dos dados já vem geocodificada.

## Próximos passos

- [ ] Buscar histórico mais longo (últimos 90 dias) para popular baseline regional
- [ ] Documentar limites de rate da API (não testado nesta validação)
- [ ] Validar refresh de token e estabilidade em uso contínuo (Cloud Function rodando 24/7)

## Artefatos

- `samples/sample_bahia.json` — 100 ocorrências recentes de BA
- `samples/sample_pará.json`, `sample_pernambuco.json`, `sample_rio_de_janeiro.json` — backups
- `samples/coverage_full.json` — sumário consolidado
