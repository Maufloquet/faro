# Fase 0 — Validação de Premissas

**Status atual: ATIVA**

Esta fase precisa ser concluída antes de qualquer linha de código de produto. As cinco validações abaixo, em paralelo, determinam se o projeto continua no caminho B2C-first, pivota para B2B-first ou é arquivado.

Prazo total estimado: **3-4 semanas**.

---

## Checklist de validações

### 1. Auditoria de dados da SSP

**Diretório:** `ssp_audit/`
**Status:** TODO
**Critério de aprovação:** dados estruturados ou semiestruturados da cidade piloto, com granularidade ≤ bairro e atualização ≥ mensal.

### 2. Teste de cobertura do Fogo Cruzado

**Diretório:** `fogo_cruzado_test/`
**Status:** TODO
**Critério de aprovação:** API responde com dados geocodificados, cobertura inclui cidade piloto OU cidade alternativa viável.

### 3. Teste de custo de Geocoding em volume

**Diretório:** `geocoding_costs/`
**Status:** TODO
**Critério de aprovação:** custo escalado ≤ R$ 800/mês para o volume projetado do MVP.

### 4. Consulta jurídica inicial

**Diretório:** `telegram_legal/`
**Status:** TODO
**Critério de aprovação:** parecer escrito de advogado cobrindo (a) base legal LGPD para geolocalização sensível, (b) viabilidade de scraping de Telegram público, (c) exposição civil "o app disse que estava seguro".

### 5. Conversa exploratória B2B

**Diretório:** `b2b_discovery/`
**Status:** TODO
**Critério de aprovação:** ao menos 1 de 3 clientes potenciais demonstra disposição concreta de pagar (não "interessante", não "manda proposta") por um serviço de inteligência de risco urbano.

---

## Gate de decisão final

Após as 5 validações, decidir entre 3 caminhos:

**A — Continuar como B2C-first**
Validações 1, 2, 3 aprovadas. Validação 4 sem bloqueio. Validação 5 ainda incerta. Iniciar Fase 1 (MVP modo passivo).

**B — Pivotar para B2B-first**
Validações 1, 2, 3 aprovadas. Validação 5 forte (cliente disposto). Construir API e dashboard B2B, deixar B2C como extensão.

**C — Arquivar**
Validação 1 falha (sem dados públicos viáveis) E validação 5 falha (sem dor B2B real). O projeto não tem fundação técnica nem de receita.

A decisão é registrada em `findings.md` com data, motivo e dados que sustentam a escolha.

---

## Princípios de execução desta fase

- **Sem código de produto.** Scripts de validação (Python, requests) são OK. Flutter, Firebase, Cloud Functions ficam para Fase 1.
- **Documentar à medida que avança.** Cada README de subdiretório vira um relatório curto ao fim.
- **Tempo, não perfeição.** 1-2 fins de semana por validação. Se travar > 1 semana em uma, registrar bloqueio e seguir.
- **Não pular validações.** Cada uma cobre um vetor de morte do projeto.
