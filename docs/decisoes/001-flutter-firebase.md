# ADR-001 — Flutter + Firebase como stack base

**Data:** 2026-05-10 (retroativo a decisão de Fase 0)
**Status:** Aceito

## Contexto

Faro é um app mobile com requisitos: cross-platform (Android + iOS),
mapa em tempo real, push notifications, autenticação anônima, latência
baixa pra UX, custo de operação compatível com bootstrap pré-receita.

Eu sou desenvolvedor solo. Não há equipe pra dividir frontend nativo
iOS + Android + backend dedicado + DevOps.

## Alternativas consideradas

1. **Nativo (Kotlin/Swift) + backend dedicado (Node ou Go em VPS)** —
   melhor performance, controle total. Custo de tempo prohibitivo pra
   solo dev: duas codebases de UI + infra própria.
2. **React Native + Supabase/PocketBase** — RN tem performance pior pra
   mapas (Google Maps RN é instável). Supabase é ótimo mas push e
   triggers exigem mais wiring.
3. **Flutter + Firebase** — uma codebase, mapas nativos, BaaS maduro,
   serverless por padrão, free tier generoso pra fase MVP.

## Decisão

**Flutter + Firebase.**

- App: Flutter 3.11+, Dart, Riverpod 3 pra state mgmt.
- Backend: Firebase (Authentication, Firestore, Cloud Functions Node 22,
  Cloud Messaging, Storage, Crashlytics, Analytics).
- Mapas: google_maps_flutter.

## Consequências

**Positivas:**
- Time-to-market acelerado (uma codebase).
- Custo inicial ~zero (free tier).
- Stack alinhada à minha experiência (já desenvolvi Datestre em Flutter+Firebase).
- Cloud Functions resolvem moderação e ingestão sem backend dedicado.

**Negativas:**
- Lock-in no Google Cloud. Sair custa reescrita.
- Free tier tem limites; cresce com uso. Migração futura pra GCP pago
  ou outro backend pode ser necessária na Fase 3+.
- Performance mobile inferior a nativo em casos extremos (animações
  complexas, processamento pesado). Não é gargalo no escopo atual.

## Revisão

Revisar antes da Fase 3 (B2B mínimo) se uso ultrapassar US$50/mês
sustentado. Avaliar Cloud Run + Firestore self-hosted ou backend dedicado.
