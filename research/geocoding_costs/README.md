# Teste de Custo de Geocoding em Volume

## Objetivo

Medir o custo real do Google Geocoding no padrão de uso projetado e validar se a estratégia alternativa (dicionário local de bairros + fuzzy match) reduz custo o suficiente.

## Por que importa

Google Geocoding cobra ~R$ 0,03-0,05 por chamada após cota grátis. No volume projetado do MVP (scraping a cada 30min em 3 portais + 500 reports/dia + reclassificações), o custo escala rápido para R$ 1.500-3.000/mês — antes da primeira receita.

O relatório v3 (§9.1) propõe geocoding offline com dicionário de bairros + Geocoding como fallback, com redução estimada de 70-85% das chamadas pagas. Esta validação confirma o número.

## Critério de aprovação

Cenário B (dicionário + fallback) tem custo total escalado **≤ R$ 800/mês** para o volume do MVP, mantendo precisão de geocoding ≥ 85%.

## Plano de teste

### Cenário A — baseline (Google Geocoding direto)

- Coletar lista de 500 textos reais de notícias com menções a localizações em uma cidade brasileira (Salvador prioridade)
- Rodar 100% pelo Google Geocoding API
- Medir:
  - Custo total (real, em USD)
  - Latência média e p95
  - Taxa de sucesso (encontrou coordenada utilizável)
  - Erros de geocoding evidente (coordenada errada para o bairro mencionado)

### Cenário B — proposta (dicionário + fallback)

- Pré-popular dicionário de bairros da cidade alvo: nome → centro lat/lng (fonte: IBGE ou OpenStreetMap)
- Para cada texto:
  1. Extrair menção de bairro/local com regex + lista do dicionário
  2. Match exato → resolve local
  3. Match fuzzy (Levenshtein ratio > 0.85) → resolve local
  4. Sem match → fallback para Google Geocoding API
- Medir:
  - % de chamadas resolvidas localmente (sem custo)
  - Custo total das chamadas residuais
  - Precisão comparada ao cenário A

### Implementação sugerida (script a criar em `test_volume.py`)

Uso de Python + requests + thefuzz (Levenshtein). Salvar resultados em CSV.

### Resultado em `findings.md`

Tabela comparativa:

| Métrica | Cenário A (baseline) | Cenário B (proposta) |
|---|---|---|
| Total de chamadas pagas | 500 | ? |
| Custo total (R$) | ? | ? |
| Custo escalado /mês | ? | ? |
| Precisão | ? % | ? % |
| Latência média | ? ms | ? ms |

Decisão: cenário B aprovado se custo escalado ≤ R$ 800/mês com precisão ≥ 85%.

## Tempo estimado

1-2 dias (8-16 horas).

## Status

TODO — não iniciado.
