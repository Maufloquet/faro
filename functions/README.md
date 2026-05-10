# `functions/` — Firebase Cloud Functions (vazio)

## O que vai aqui

Pipelines de ingestão, classificação e cálculo de risco em tempo real. Stack: Node.js + TypeScript em Cloud Functions v2.

Funções mínimas previstas para Fase 1:
- `ingestFogoCruzado` — scheduler horário
- `ingestSSPHistorical` — execução diária
- `classifyReport` — trigger no Firestore quando report é criado
- `recomputeRiskScore` — transaction quando reports mudam de estado
- `expireStaleReports` — scheduler de 4h

## Quando começar

**Apenas após o gate da Fase 0 ser aprovado.**

## Por que está vazio

Cada Cloud Function tem custo fixo de manutenção (deploy, observabilidade, testes). Construir antes de validar fontes de dados gera código que pode não ter o que processar.
