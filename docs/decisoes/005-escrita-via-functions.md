# ADR-005 — Escrita em `occurrences` só via Cloud Functions

**Data:** 2026-05-10
**Status:** Aceito

## Contexto

Firestore permite que apps clientes escrevam direto na collection com
permissão. Mas `occurrences` é o coração editorial do Faro: cada doc
ali é tratado como "fato" pela UI e por push notifications.

Permitir escrita direta do cliente abriria:

1. **Spam** — qualquer usuário autenticado (mesmo anonymous) poderia
   inflar relatos.
2. **Geolocalização forjada** — cliente poderia escrever doc com
   coordenadas arbitrárias.
3. **Doc-id colisão** — escrita direta sem coordenação levaria a colisões
   ou duplicações.
4. **Auditoria pobre** — sem ponto único de entrada, fica difícil
   rastrear de onde veio cada dado.

## Alternativas consideradas

1. **Escrita direta com rules estritas** — Firestore rules têm
   capacidade limitada de validação. Não dá pra validar coordenada
   contra um geocoder, por exemplo. Insuficiente.
2. **Escrita direta + Cloud Function de moderação async** — escrita
   imediata, moderação assíncrona. Latência de remoção vira janela
   de exposição a spam.
3. **Escrita só via Cloud Functions (admin SDK)** — toda ocorrência
   passa por Function, que enriquece (geohash, weight, expiresAt),
   valida (security_related, confidence ≥ 0.55) e grava com doc-id
   determinístico.

## Decisão

**Toda escrita em `occurrences` passa por Cloud Function.** Firestore
rule é `allow write: if false`.

Pontos de entrada:
- `fogoCruzadoSync` (scheduler) — pull da API Fogo Cruzado
- `ingestNewsBahia` (scheduler) — pull RSS + classificação Groq
- `backfillFogoCruzado` (HTTP one-shot) — histórico manual

Reports de usuário (V2) entrarão em `/reports/` e serão promovidos a
`occurrences` por uma Cloud Function de moderação que aplica reputação
e validação coletiva. Ver ADR-002.

## Consequências

**Positivas:**
- Schema garantido: toda doc tem geohash, weight, expiresAt, source.
- Doc-id determinístico (`media-${hash}`) → idempotência natural.
- Ponto único de auditoria.
- Spam impossível pelo path do cliente.

**Negativas:**
- Latência de novos relatos depende de scheduler (30 min pro media,
  intervalo do Fogo Cruzado pro sync). Não é crítico no MVP modo passivo.
- Cold start de Cloud Function adiciona segundos ao primeiro hit do dia.

## Revisão

Reabrir na Fase 2 quando reports de usuário entrarem: a Function de
moderação vai precisar de design separado (rate limit por usuário,
detecção de duplicatas geográficas, reputação).
