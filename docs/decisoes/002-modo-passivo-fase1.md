# ADR-002 — Modo passivo na Fase 1 (sem reports diretos de usuário)

**Data:** 2026-05-10
**Status:** Aceito

## Contexto

A camada 4 do relatório (UGC — relatos de usuários) é estrategicamente
poderosa: aumenta densidade de dados e cria network effect. Mas tem
riscos: spam, denúncia falsa, viés de comunidade (apenas certos perfis
reportam), responsabilidade legal por conteúdo de terceiros.

Na Fase 1 (MVP modo passivo), a meta é validar **adoção** e **retenção D7
> 30%** sem assumir os riscos de moderação prematura. A pergunta da Fase 1
é "o produto entrega valor sem UGC?", não "o produto funciona com UGC?".

## Alternativas consideradas

1. **UGC desde dia 1** — maximiza dados e engajamento. Custo: precisa
   moderação ativa (LLM + humano), termos legais robustos, tooling de
   denúncia/contestação. Risco editorial sério se um report falso viralizar.
2. **UGC com aprovação manual** — reduz risco mas mata velocidade (o valor
   do UGC é justamente o tempo real).
3. **Modo passivo: só consumo de fontes oficiais (Fogo Cruzado + media)**
   na Fase 1. UGC volta na Fase 2 ("Validação social") com base validada.

## Decisão

**Modo passivo na Fase 1.** Reports diretos de usuário bloqueados na
Firestore rule (`allow write: if false` em `/reports/`). O app não tem
botão "Reportar" implementado. Toda ocorrência vem de Cloud Functions
via Fogo Cruzado ou ingestão de notícias.

## Consequências

**Positivas:**
- Sem custo de moderação na Fase 1.
- Sem risco legal de conteúdo de terceiros.
- Retenção testada num produto editorialmente seguro.
- Fogo Cruzado + media (Camadas 1+2) já dão densidade razoável em Salvador.

**Negativas:**
- Sem network effect direto na Fase 1.
- Áreas fora da cobertura de Fogo Cruzado parecem "sem nada acontecendo"
  (mitigação: copy editorial "ausência de relatos ≠ segurança").

## Revisão

Reabrir reports de usuário na Fase 2, com:
- Sistema de reputação invisível
- Validação coletiva (confirmar/contestar 2 toques)
- Expiração automática 4h pra relatos não confirmados
- Termos + RIPD assinados (Validação 4 jurídica)
