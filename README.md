# Faro (provisório)

[![Flutter CI](https://github.com/Maufloquet/faro/actions/workflows/flutter.yml/badge.svg)](https://github.com/Maufloquet/faro/actions/workflows/flutter.yml)
[![Functions CI](https://github.com/Maufloquet/faro/actions/workflows/functions-test.yml/badge.svg)](https://github.com/Maufloquet/faro/actions/workflows/functions-test.yml)

App de alerta de segurança urbana — assistente de decisão em tempo real.

> **"O que está acontecendo perto de mim agora, e devo evitar passar por ali?"**
> Combinação de dados públicos, relatos de usuários e sinais passivos urbanos. **Nunca afirma segurança** — apenas comunica probabilidade e ausência de relatos.

> Nome **provisório**: "Faro". Razão: conciso (4 letras), brasileiro, sensorial, sugere percepção sem prometer segurança. Confirmação pendente via busca formal no INPI nas classes 9 (apps) e 42 (software).

---

## Status atual

**Fase 1 — MVP modo passivo** — tecnicamente pronto pra beta fechado (2026-05-23).

O servidor está deployado em produção. Cobertura: Salvador + RMS (Camaçari, Lauro de Freitas, Simões Filho). Falta apenas setup de TestFlight / Play Internal Track + convites — ver `docs/beta_launch_checklist.md`.

Fase 0 (Validação de Premissas) concluída em 2026-05-10. Validações 4 (jurídico) e 5 (B2B) foram puladas — bloqueiam a V1 pública, não o beta fechado.

---

## O que o app faz hoje

### Fontes de dados (rodando 24/7)

- **14 portais de notícia** baianos via RSS + Google News, classificados por LLM (Llama 3.1 8B via Groq) a cada 30 min
- **Fogo Cruzado** — registros oficiais de tiroteio na BA, sync a cada 30 min
- **OpenStreetMap Notes** — anotações de moradores, ingest diário
- **OpenStreetMap Overpass** — infraestrutura urbana (delegacias, hospitais, postes, comércio 24h), refresh semanal

### Inteligência editorial

- **Geocoding robusto**: whitelist explícita de cidades, validação cross-text (cidade e bairro têm que aparecer literalmente na matéria), match restrito ao dict da cidade indicada
- **Dedup semântico cross-source**: embeddings Gemini `text-embedding-004` (768d) + Firestore Vector Search. Mesma matéria em 5 portais vira 1 ocorrência corroborada
- **Narrativas semanais**: clustering automático de relatos relacionados — "Esta semana — 6 relatos relacionados em Garcia"
- **Tendência histórica por bairro**: cada bairro comparado consigo mesmo no tempo, nunca veredito territorial
- **Densidade populacional** (Censo IBGE 2022 + PDDU 2010): normaliza relatos por 10k habitantes pra blindar de viés
- **Tom editorial**: testes automatizados garantem que nada gerado pelo app contém PERIGO/CUIDADO/EVITE/URGENTE

### Notificações

- **Proximidade** (estilo Waze): push quando ocorrência cai em raio de 1km, via FCM topic por geohash5. Tracking em background opt-in
- **Resumo diário às 7h**: push personalizado por usuário com base no bairro principal + favoritos. Silêncio honesto se não houver nada
- **Catch-up no cruzamento de célula**: ao mudar de área, app verifica relatos recentes locais

### Perfil e personalização

- **Anonymous-first** — UID estável no device, sem cadastro obrigatório
- **Login Google opcional** — só pra sync cross-device
- **Perfil opcional**: como você se locomove (6 modos), horários típicos (5 faixas), bairro principal, nome
- **Onboarding em 4 passos**: aceite editorial bloqueante + 3 passos de captura puláveis
- **Bairros favoritos** + endereço de referência (hotel/casa)

### Privacidade e LGPD

- Termos e Política de Privacidade em `app/assets/legal/`
- Tela "Privacidade e dados" no /Sobre: exportar dados em JSON + apagar conta com double-confirm
- Princípio: coletar o mínimo, anônimo por design, tudo opcional

### Funcionalidades

- **Mapa** com clusters dinâmicos por zoom + camadas OSM (toggle por categoria)
- **Atividade por área** (ranking não-moral): contagem, tendência histórica, top motivos, "cheguei bem"
- **Avaliar trajeto A→B**: linha reta + corredor de 500m, relatos das últimas 6h no caminho
- **Detalhe de ocorrência**: motivo, fonte, link da matéria, tendência do bairro, contestação
- **Trajetória pessoal local** — histórico de cruzamentos com zonas, no device
- **Cheguei bem**: sinal positivo anônimo agregado por (geohash5, dia)
- **Sistema de contestação** com agregação server-side (threshold de 3 UIDs distintos)
- **Widget de tela inicial** (iOS WidgetKit + Android AppWidget) com contagem do bairro principal

### Painel admin interno (oculto)

Acessível via deep link `faro://admin` após custom claim `admin: true` (script `functions/scripts/grantAdmin.js`):

- Usuários: total, anônimos vs Google, ativos 24h/7d
- Ocorrências: total, breakdown por fonte/cidade/motivo, contestadas
- Contestações, "cheguei bem"
- Saúde dos schedulers (verde/amarelo/vermelho) — helper `runWithHealth` instrumenta todos os 8 crons

---

## Fases do roadmap

| Fase | Duração | Estado | Gate de saída |
|---|---|---|---|
| 0 — Validação de premissas | 3-4 semanas | **Concluída** ✓ | Fogo Cruzado validado em Salvador |
| 1 — MVP modo passivo | 10-12 semanas | **Ativa** (tech pronto) | Beta fechado, retenção D7 > 30% |
| 2 — Validação social | 8-10 semanas | Bloqueada por F1 | Densidade > 5 reports/km²/dia |
| 3 — B2B mínimo | 6-8 semanas | Bloqueada por F2 | 1 contrato B2B assinado, MRR > custo de infra |
| 4 — Expansão | Variável | Bloqueada por F3 | Decisão de captação ou bootstrap |

Detalhamento completo em `docs/roadmap_features.md` e `docs/relatorio_v3.pdf`.

---

## Estrutura

- `docs/` — visão, princípios editoriais, plano de crise, roadmap, setup Firebase
- `docs/beta_launch_checklist.md` — passo a passo pro beta fechado
- `docs/widget_setup.md` — passos manuais Xcode pro widget iOS
- `docs/decisoes/` — Architecture Decision Records (ADRs)
- `research/` — Validações da Fase 0 (concluídas, com findings)
- `legal/` — termos, política, RIPD, contratos B2B (versões formais)
- `design/` — linguagem visual de incerteza e wireframes
- `app/` — Flutter
- `app/assets/legal/` — termos e política embutidos no app
- `app/ios/FaroWidget/` — código Swift do widget iOS (target Widget Extension)
- `functions/` — Firebase Cloud Functions (Node.js 22)
- `functions/scripts/` — utilitários one-shot (grantAdmin, cleanupBadGeocoding, backfills)
- `infra/` — Firestore rules + indexes (incluindo vector index)
- `firebase.json` — configuração Firebase CLI (raiz)

## Como rodar localmente

### App Flutter (modo dev — sem Firebase)

```bash
cd app
flutter pub get
flutter run
```

O app inicia em modo dev por padrão (`USE_DEV_DATA=true`), lendo as ocorrências reais coletadas na Validação 2 a partir de `assets/dev_occurrences.json`. Mapa abre centrado em Salvador com 100 marcadores reais.

Para rodar com Firebase real:
```bash
flutter run --dart-define=USE_DEV_DATA=false
```

### Cloud Functions

```bash
cd functions
npm install
npm test                          # 222 testes
firebase emulators:start          # local
firebase deploy --only functions  # produção
```

### One-shots manuais (rodar após o deploy inicial)

```bash
# Sincroniza pontos de ônibus (OSM Overpass → /osm/bus_stops)
curl -X POST -H "Authorization: Bearer $(gcloud auth print-identity-token)" \
  "https://southamerica-east1-<PROJECT_ID>.cloudfunctions.net/fetchOsmBusStops"

# Popula embeddings históricos em /occurrences (dedup semântico cross-source)
curl -X POST -H "Authorization: Bearer $(gcloud auth print-identity-token)" \
  "https://southamerica-east1-<PROJECT_ID>.cloudfunctions.net/backfillEmbeddings?limit=500"

# Concede claim de admin pro seu UID (abre faro://admin no app)
gcloud auth application-default login
node scripts/grantAdmin.js <SEU_UID>
```

Pontos de ônibus mudam pouco — re-rodar `fetchOsmBusStops` a cada 3-6 meses é suficiente.

## Stack

- **Flutter** 3.x com Riverpod 3 (state), Google Maps, FCM, Crashlytics, Analytics, anonymous + Google auth
- **Firebase**: Auth, Firestore (com Vector Search nativo), Cloud Functions Node.js 22, Messaging, Hosting, Cloud Scheduler
- **LLMs**: Groq (Llama 3.1 8B) pra classificação editorial, Google Gemini `text-embedding-004` pra embeddings semânticos
- **Mapas**: Google Maps SDK
- **Fontes**: Fogo Cruzado API, OpenStreetMap (Notes + Overpass), RSS de 14 portais + Google News

## Documento de referência

`docs/relatorio_v3.pdf` — análise crítica de viabilidade e plano de execução. Toda decisão estratégica deve ser consistente com esse documento. Quando divergir, registrar em `docs/decisoes/`.
