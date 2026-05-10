# Projeto Segurança Urbana (sem nome)

App de alerta de segurança urbana — assistente de decisão em tempo real.

> **"O que está acontecendo perto de mim agora, e devo evitar passar por ali?"**
> Combinação de dados públicos, relatos de usuários e sinais passivos urbanos. **Nunca afirma segurança** — apenas comunica probabilidade e ausência de relatos.

---

## Status atual

**Fase 0 — Validação de Premissas** (em andamento, ~3-4 semanas)

Antes de qualquer linha de código, três gargalos precisam ser validados. A próxima ação concreta está em `research/README.md`.

A marca ainda não está decidida. "Zelo" foi descartada por colisão (Zelo Drive, Zelo Protege). Esta pasta usa o nome provisório `projeto-seguranca-urbana` — basta `mv` quando o nome final for fechado.

---

## Fases do roadmap

| Fase | Duração | Estado | Gate de saída |
|---|---|---|---|
| 0 — Validação de premissas | 3-4 semanas | **Ativa** | SSP utilizável OU Fogo Cruzado cobre cidade piloto |
| 1 — MVP modo passivo | 10-12 semanas | Bloqueada por F0 | Beta fechado, retenção D7 > 30% |
| 2 — Validação social | 8-10 semanas | Bloqueada por F1 | Densidade > 5 reports/km²/dia |
| 3 — B2B mínimo | 6-8 semanas | Bloqueada por F2 | 1 contrato B2B assinado, MRR > custo de infra |
| 4 — Expansão | Variável | Bloqueada por F3 | Decisão de captação ou bootstrap |

Detalhamento completo no relatório de referência (§11).

---

## Estrutura

- `docs/` — visão, princípios editoriais, plano de crise, ADRs
- `research/` — Fase 0 ativa: 5 validações com critério de aprovação
- `legal/` — termos, política de privacidade, RIPD, contratos B2B
- `design/` — linguagem visual de incerteza e wireframes
- `app/` — Flutter, vazio até Fase 1
- `functions/` — Firebase Cloud Functions, vazio até Fase 1
- `infra/` — firebase.json, rules, indexes, vazio até Fase 1

## Documento de referência

`docs/relatorio_v3.pdf` — análise crítica de viabilidade e plano de execução. Toda decisão estratégica deste projeto deve ser consistente com esse documento. Quando divergir, atualizar o relatório E o documento de decisão (`docs/decisoes/`).
