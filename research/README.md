# Fase 0 — Validação de Premissas

**Status atual: ATIVA**

Esta fase precisa ser concluída antes de qualquer linha de código de produto. As cinco validações abaixo, em paralelo, determinam se o projeto continua no caminho B2C-first, pivota para B2B-first ou é arquivado.

Prazo total estimado: **3-4 semanas**.

---

## Checklist de validações

### 1. Auditoria de dados da SSP

**Diretório:** `ssp_audit/`
**Status:** REBAIXADA — não-crítica após aprovação da Validação 2
**Justificativa:** Fogo Cruzado já cobre Salvador com 100% de geocodificação. Camada SSP-BA vira complementar (histórico de longo prazo), não crítica. Pode ser feita em paralelo à Fase 1 ou após o MVP.
**Critério de aprovação:** dados estruturados ou semiestruturados da cidade piloto, com granularidade ≤ bairro e atualização ≥ mensal.

### 2. Teste de cobertura do Fogo Cruzado

**Diretório:** `fogo_cruzado_test/`
**Status: APROVADA** (2026-05-10) — ver `fogo_cruzado_test/findings.md`
**Resultado:** 4 estados cobertos, 100% com geocoordenadas. **Salvador domina BA com 78 de 100 ocorrências recentes** (~3/dia). Densidade comparável a RJ. Salvador confirmada como piloto recomendado.

### 3. Teste de custo de Geocoding em volume

**Diretório:** `geocoding_costs/`
**Status:** PRONTO PARA RODAR — `bairros_salvador.json` já populado (152 bairros via OSM). Falta API key + 500 textos reais.
**Próximo passo:** habilitar Geocoding API no GCP, preencher `.env`, popular `sample_texts.txt`, executar `python test_volume.py`
**Critério de aprovação:** custo escalado ≤ R$ 800/mês para o volume projetado do MVP.

### 4. Consulta jurídica inicial — PULADA (decisão do autor, 2026-05-10)

**Diretório:** `telegram_legal/`
**Status:** PULADA — retomar antes do beta público
**Justificativa:** decisão do autor de seguir para desenvolvimento técnico antes do parecer jurídico. **Risco aceito:** sem parecer, decisões de arquitetura sobre Telegram MTProto e tratamento de geolocalização ficam tentativas; podem precisar de retrabalho. Esta validação **deve** ser executada antes do beta público (com usuários reais) — sob pena de exposição LGPD não mitigada.
**Reativação obrigatória:** quando modelo de dados estiver definido E antes do primeiro beta com usuários externos.

### 5. Conversa exploratória B2B — PULADA (decisão do autor, 2026-05-10)

**Diretório:** `b2b_discovery/`
**Status:** PULADA — retomar quando MVP tiver demo navegável
**Justificativa:** decisão do autor de seguir B2C-first antes de validar disposição de pagamento B2B. **Risco aceito:** caminho B2B alternativo não validado; se MVP B2C não engajar, opção B2B precisará ser reaberta como pivô, não como saída paralela.
**Reativação obrigatória:** quando MVP tiver demo navegável com dados reais (~Fim Fase 1).

---

## Gate de decisão final (revisado — apenas 1, 2, 3)

Validações 4 e 5 puladas por decisão do autor. Decisão simplificada:

**A — Continuar como B2C-first** (caminho ativo)
Validações 1, 2, 3 aprovadas → iniciar Fase 1 (MVP modo passivo). É o caminho assumido.

**C — Arquivar**
Validação 1 falha (sem dados públicos viáveis em nenhuma cidade) E validação 2 falha (Fogo Cruzado sem cobertura útil). Sem dados, modo passivo não funciona.

Caminho B (B2B-first) reaberto apenas se Fase 1 mostrar engajamento ruim e validação 5 for retomada nesse contexto.

A decisão é registrada em `findings.md` com data, motivo e dados que sustentam a escolha.

---

## Princípios de execução desta fase

- **Sem código de produto.** Scripts de validação (Python, requests) são OK. Flutter, Firebase, Cloud Functions ficam para Fase 1.
- **Documentar à medida que avança.** Cada README de subdiretório vira um relatório curto ao fim.
- **Tempo, não perfeição.** 1-2 fins de semana por validação. Se travar > 1 semana em uma, registrar bloqueio e seguir.
- **Não pular validações.** Cada uma cobre um vetor de morte do projeto.
