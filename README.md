# Faro (provisório)

[![Flutter CI](https://github.com/Maufloquet/faro/actions/workflows/flutter.yml/badge.svg)](https://github.com/Maufloquet/faro/actions/workflows/flutter.yml)
[![Functions CI](https://github.com/Maufloquet/faro/actions/workflows/functions-test.yml/badge.svg)](https://github.com/Maufloquet/faro/actions/workflows/functions-test.yml)

App de alerta de segurança urbana — assistente de decisão em tempo real.

> **"O que está acontecendo perto de mim agora, e devo evitar passar por ali?"**
> Combinação de dados públicos, relatos de usuários e sinais passivos urbanos. **Nunca afirma segurança** — apenas comunica probabilidade e ausência de relatos.

> Nome **provisório**: "Faro". Razão: conciso (4 letras), brasileiro, sensorial, sugere percepção sem prometer segurança. Confirmação pendente via busca formal no INPI nas classes 9 (apps) e 42 (software).

---

## Status atual

**Fase 1 — MVP modo passivo** (em andamento)

Fase 0 (Validação de Premissas) concluída em 2026-05-10. A camada base de dados (Fogo Cruzado) está validada e cobre Salvador. Validações 4 (jurídico) e 5 (B2B) foram puladas — devem ser retomadas antes do beta público.

---

## Fases do roadmap

| Fase | Duração | Estado | Gate de saída |
|---|---|---|---|
| 0 — Validação de premissas | 3-4 semanas | **Concluída** ✓ | Fogo Cruzado validado em Salvador |
| 1 — MVP modo passivo | 10-12 semanas | **Ativa** | Beta fechado, retenção D7 > 30% |
| 2 — Validação social | 8-10 semanas | Bloqueada por F1 | Densidade > 5 reports/km²/dia |
| 3 — B2B mínimo | 6-8 semanas | Bloqueada por F2 | 1 contrato B2B assinado, MRR > custo de infra |
| 4 — Expansão | Variável | Bloqueada por F3 | Decisão de captação ou bootstrap |

Detalhamento completo no relatório de referência (§11).

---

## Estrutura

- `docs/` — visão, princípios editoriais, plano de crise
- `docs/decisoes/` — Architecture Decision Records (ADRs)
- `research/` — Validações da Fase 0 (concluídas, com findings)
- `legal/` — termos, política, RIPD, contratos B2B (placeholders)
- `design/` — linguagem visual de incerteza e wireframes
- `app/` — Flutter (Fase 1, em andamento)
- `functions/` — Firebase Cloud Functions (Fase 1, em andamento)
- `infra/` — Firestore rules + indexes
- `firebase.json` — configuração Firebase CLI (raiz)

## Como rodar localmente

### App Flutter (modo dev — sem Firebase)

```bash
cd app
flutter pub get
flutter run
```

O app inicia em modo dev por padrão (`USE_DEV_DATA=true`), lendo as ocorrências reais coletadas na Validação 2 a partir de `assets/dev_occurrences.json`. Mapa abre centrado em Salvador com 100 marcadores reais.

Para rodar com Firebase real (após configurar):
```bash
flutter run --dart-define=USE_DEV_DATA=false
```

### Cloud Functions (precisa Firebase project)

```bash
cd functions
npm install
firebase emulators:start  # local
firebase deploy --only functions  # produção
```

### One-shots manuais (rodar uma vez no setup)

Após o deploy inicial das Functions, rodar:

```bash
# Sincroniza pontos de ônibus (OSM Overpass → /osm/bus_stops)
curl -X POST -H "Authorization: Bearer $(gcloud auth print-identity-token)" \
  "https://southamerica-east1-<PROJECT_ID>.cloudfunctions.net/fetchOsmBusStops"

# (opcional) Mescla duplicatas históricas em /occurrences
curl -X POST -H "Authorization: Bearer $(gcloud auth print-identity-token)" \
  "https://southamerica-east1-<PROJECT_ID>.cloudfunctions.net/backfillDedup?dryRun=true"
```

Pontos de ônibus mudam pouco — re-rodar `fetchOsmBusStops` a cada 3-6 meses é suficiente.

## Documento de referência

`docs/relatorio_v3.pdf` — análise crítica de viabilidade e plano de execução. Toda decisão estratégica deve ser consistente com esse documento. Quando divergir, registrar em `docs/decisoes/`.
