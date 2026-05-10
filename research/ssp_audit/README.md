# Auditoria de Dados Públicos da SSP

## Objetivo

Verificar se a Secretaria de Segurança Pública da cidade piloto disponibiliza dados estruturados de ocorrências com granularidade e frequência suficientes para popular o mapa do app antes do primeiro usuário.

## Por que isso é gargalo

O modelo passivo do produto (§3 do relatório v3) depende de baseline histórico real. Sem dados públicos utilizáveis, o app abre com mapa vazio e o cold start vira existencial.

## Critério de aprovação

Dados que atendam **todos** os critérios abaixo:
- Estruturados (CSV, JSON, API REST) ou semiestruturados (PDF mensal parseável com layout consistente)
- Granularidade espacial ≤ bairro (idealmente ≤ quadra)
- Atualização ≥ mensal
- Cobertura de pelo menos uma cidade da Bahia (piloto provável) OU outra cidade viável

## Plano de auditoria

### Cidade piloto provável: Salvador (BA)

1. Acessar portal SSP-BA: <https://www.ssp.ba.gov.br>
2. Procurar seção de "estatísticas", "dados abertos", "transparência"
3. Verificar formato (PDF / CSV / API), granularidade espacial e temporal
4. Tentar extrair 1 mês de dados como amostra

### Backups se SSP-BA falhar

| Estado | Fonte | Url provável |
|---|---|---|
| RJ | ISP-RJ (Instituto de Segurança Pública) | <http://www.ispdados.rj.gov.br> |
| PE | Fogo Cruzado + SDS-PE | <https://api.fogocruzado.org.br> |
| SP | SSP-SP (PDFs mensais agregados) | <https://www.ssp.sp.gov.br/estatistica> |
| MG | SSPMG | <http://www.seguranca.mg.gov.br> |

### Para cada fonte avaliada, registrar em `samples/<estado>_audit.md`:

- URL exato dos dados
- Formato disponível
- Granularidade espacial (município / bairro / quadra / coordenada)
- Granularidade temporal (anual / mensal / semanal / diário)
- Última atualização disponível
- Tem licença de uso clara?
- Exige cadastro / API key?
- Tipos de ocorrência cobertos
- 1 amostra real baixada e salva em `samples/<estado>_sample.{csv,pdf,json}`

## Tempo estimado

1 fim de semana (8-12 horas), considerando que muitas SSPs exigem busca em portais mal indexados.

## O que NÃO fazer nesta etapa

- Não construir scraper completo. Apenas validar que os dados existem e são acessíveis.
- Não geocodificar tudo. Verificar se já vem com lat/lng ou se precisa converter.
- Não decidir cidade piloto agora. Coletar evidência de 2-3 estados antes de escolher.

## Status

TODO — não iniciado.
