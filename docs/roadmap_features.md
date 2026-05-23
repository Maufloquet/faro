# Roadmap de Features

Banco de ideias estruturado, atualizado quando aparecem propostas que não cabem agora mas valem registro.

Status atual (sessão de 2026-05-16): MVP **tecnicamente pronto pra beta fechado, com tracking Waze-like fechado**. Falta apenas setup manual do usuário (Run Script Xcode dSYM) e itens externos (jurídico, INPI, conselho editorial). Secrets do GitHub e Crashlytics no console já foram aplicados. Gate da Fase 1 ("Beta fechado, retenção D7 > 30%") só pode ser medido após convidar usuários reais.

**Itens fechados nesta sessão (2026-05-16):** Background location tracking (estilo Waze) com opt-in progressivo no `/sobre/`, FCM resubscribe ao cruzar célula geohash5, catch-up via query Firestore por relatos recentes na nova célula, notificações locais com copy editorial. Camada 7 (IBGE) adicionada — densidade populacional por bairro de Salvador.

**Itens fechados em 2026-05-14:** Crashlytics + Analytics com cobertura completa de screen_view, cluster manager (zoom 14.5-17), CI/CD com build iOS + deploy auto de Functions + preflight de secrets, suite real de 28 testes substituindo o placeholder, roadmap sincronizado.

---

## Camadas de dados (estende a fundação)

### Camada 2 — Scraping de portais de notícia
**Status:** em produção · cobertura BA + RJ + PE + SP (2026-05-21)
**Peso no score:** 0.3
**Detalhes:**
- Cloud Function `ingestNewsBahia` (nome legado, scheduler 30min) + Google News RSS + Groq pra extrair localização + dicionário local de bairros (RMS) ou centroide de cidade.
- Bahia tem cobertura plena com dict de bairros (`bairros_*.json` na RMS).
- RJ/PE/SP entram via Google News + G1 estadual, com geocoding caindo no centroide da cidade (dict de bairros pra essas regiões é TODO). UI já trata centroide de cidade com círculo de incerteza.
- `state` da ocorrência inferido dinamicamente via `stateForCity(geo.cityKey)` (`cityCentroids.js`), sem hardcode.
- **TODO**: dict de bairros pra Rio/Recife/SP, fontes locais por capital (O Dia, Diário de Pernambuco, Folha de S.Paulo).

### Camada 3 — Monitoramento de Telegram público
**Status:** bloqueado por parecer jurídico (Validação 4 pulada)
**Peso no score:** 0.4
**Detalhes:** Bot via MTProto (biblioteca Telethon) em Python. Monitora grupos públicos de segurança da região. Antes de implementar, precisa de parecer sobre LGPD + termos do Telegram.

### Camada 4 — UGC (relatos de usuários)
**Status:** V2, bloqueado por base de usuários
**Peso no score:** 0.3 a 1.0 (dinâmico por reputação)
**Detalhes:** Botão "reportar" com GPS obrigatório, validação coletiva (confirmar/contestar com 2 toques), expiração automática de relatos não confirmados em 4h, sistema de reputação invisível pro usuário.

### Camada 5 — SSP estadual
**Status:** rebaixado de crítico — Fogo Cruzado supre o piloto
**Peso no score:** 0.5
**Detalhes:** Auditoria caso a caso. SSP-BA via Transparência Bahia (painel, sem API estruturada). ISP-RJ tem dados abertos maduros. SDS-PE via Fogo Cruzado.

### Camada 6 — OSM Overpass (contexto urbano)
**Status:** Implementada em 2026-05-21 (cron semanal adicionado em 2026-05-21)
**Peso editorial:** alto — destrava o discurso "Faro mostra infraestrutura, não veredito"
**Detalhes:**
- Pontos de ônibus já estavam (`fetchOsmBusStops`, doc `/osm/bus_stops`).
- 4 categorias via `fetchOsmInfra` (HTTP manual, `?kinds=police,hospitals,…`) e `syncOsmInfra` (scheduler semanal, segunda 04:30) em `functions/lib/osmInfraIngest.js`. Cada uma vira doc em `/osm/{kind}`: `police`, `hospitals`, `street_lamps`, `commerce_24h`. O core (`runInfraSync`) é compartilhado entre os dois pontos de entrada.
- Bbox da RMS (Salvador + Camaçari + Lauro + Simões) pra delegacias/hospitais/comércio; bbox menor (Salvador urbano) pra postes — `highway=street_lamp` tem milhares de nós e a RMS inteira poluiria sem ganho.
- Cliente Flutter: `OsmInfra` (modelo único com factory), `osmInfraProvider(kind)` (Riverpod família, lazy). Toggle individual por camada no `LayersSheet`, com nota editorial explicando que cobertura OSM é desigual.
- Cada categoria tem zoom mínimo próprio (`_infraMinZoom` em `map_screen.dart`): delegacias/hospitais a partir de 13, comércio 14, postes 16.5 — evita poluir vista panorâmica.
- Markers em cores neutras (azul polícia, rosa hospitais, verde comércio, amarelo postes) com `InfoWindow` mostrando nome + tag relevante (operator, emergency, brand). Postes não têm InfoWindow (só posição importa).
- 10 testes unitários cobrem o parser em `functions/test/osmInfraIngest.test.js`.

### Camada 7 — IBGE: densidade populacional por bairro
**Status:** Cobertura expandida em 2026-05-20 (129/159 bairros de Salvador) + populações municipais da RMS adicionadas em 2026-05-21
**Peso editorial:** crítico — blinda Faro de viés territorial
**Detalhes:**
- Asset `app/assets/bairros_pop_salvador.json` cobre 129 dos 159 bairros do dict de Salvador. Schema por entrada: `{population, source, confidence}`.
- Dois níveis de confiança:
  - `verified` — valor publicado pelo Censo 2022 via imprensa (Itapuã, Pituba, Pernambués por ora).
  - `estimated` — população da Prefeitura-Bairro do PDDU (Censo 2010, fonte cms.ba.gov.br/uploads/pddu/pdduquadro09.pdf) dividida igualmente entre os bairros listados na Wikipedia (Subdivisões de Salvador).
- 30 bairros do dict de Salvador não constam em nenhuma PB da Wikipedia e ficam sem dado — UI esconde a normalização nesse caso.
- Nova seção `_cities` no asset (2026-05-21) com população municipal dos 4 municípios da RMS (Censo 2022 IBGE): Salvador 2.418.005, Camaçari 300.372, Lauro de Freitas 203.334, Simões Filho 114.559. Permite contexto editorial pra relatos que caem no centroide de cidade (bairro=null).
- `DensityService` mantém `populationFor`, `per10kInhabitants`, `isEstimated(bairro)` e ganha `populationForCity(city)`. A doc do método deixa explícito: **não use pop municipal como denominador de per10k de bairro** — é matemática errada.
- Exposição na UI: `AreasScreen` exibe `~X.X relatos por 10 mil habitantes` em cada card de bairro. `OccurrenceDetailSheet` mostra a população do bairro como contexto editorial (`~X mil habitantes`). Ambas em linha discreta com `~` para estimativas e tooltip distinguindo as fontes.
- **Decisão de design (2026-05-21):** *não* adicionamos bairros granulares de Camaçari/Lauro/Simões porque (a) há colisão de nomes (ex: "Itinga" existe em Salvador e em Lauro), e (b) divisão simples entre poucos bairros do dict daria números enganosos. População municipal cobre o contexto editorial sem inventar dados.
- **TODO**: quando Censo 2022 sair com agregação bairro-granular, substituir as estimativas de Salvador por valores `verified`; pedir o dataset oficial CONDER por ofício pra refinar a distribuição dentro das PBs; usar `populationForCity` na UI pra ancorar relatos com bairro=null da RMS.

---

## Motoristas de aplicativo (B2C + B2B)

Anotado em 2026-05-11. Ideia: app pode ser ferramenta forte pra entregadores e motoristas. Discutido com nuance editorial.

### B2C — funções pro motorista individual

- **"Avaliar corrida antes de aceitar"** — Motorista cola endereço de destino → app retorna em 2s: relatos da área nas últimas 24h + tipo predominante + tendência. Ele decide informado.
- **Modo dirigindo (handsfree)** — UI simplificada quando velocidade > 20 km/h. Só alerta sonoro/vibração quando entra em área com relato confirmado em < 6h.
- **"Onde parar entre corridas"** — Motorista parado > N min, app sugere 3 pontos próximos com menos atividade recente.
- **Rota com filtro de risco** — Integração com navegação. "Essa rota passa por 3 relatos de hoje, prefere alternativa que adiciona 4 min?"
- **Histórico pessoal local** — No device, não no server. "É a 3ª vez que você passa por esta zona essa semana." Privado por design.

### B2B — produtos pra plataformas

| Cliente | Dor | Entrega | Valor estimado |
|---|---|---|---|
| Apps de delivery (iFood, 99Food) | Roubo de entregadores + carga | API REST de risk score em tempo real | R$ 5-15k/mês/cidade |
| Logística última milha (Loggi, Total Express) | Sinistros + seguros | API + dashboard de frota com heatmap histórico por horário | R$ 3-8k/mês |
| Seguradoras de moto | Precificação dinâmica | Score por região por horário pra ajustar prêmios | Por volume |
| Cooperativas de motoristas | Não-discriminação + segurança coletiva | Dashboard interno + alerta colaborativo | R$ 1-3k/mês |

### Cuidados editoriais críticos

- **NUNCA** criar feature que dê veredito "recuse essa corrida"
- Discriminação territorial é ilegal (Lei de Mobilidade Urbana) + viola TOS de Uber/99/iFood
- Periferias já têm menos cobertura de serviços; app não pode reforçar exclusão
- Sempre entregar **contexto**, não **julgamento**
- Copy: "X relatos na semana", nunca "área perigosa"
- Modo "passei e tudo bem" pós-corrida: contra-dados que evitam viés acumulado

### Antes de implementar

1. **Validação 5** (B2B discovery, pulada na Fase 0): conversar com 3 motoristas reais de Salvador
2. **Validação 4** (parecer jurídico, pulada): limite de responsabilidade civil se motorista sofrer incidente em área não-marcada pelo app

---

## Passageiros de ônibus (audiência prioritária)

Anotado em 2026-05-11. Audiência mais importante numericamente — maioria da população urbana brasileira anda de ônibus, não Uber/carro. Soluções de mobilidade tendem a esquecer essa galera; Faro tem espaço editorial forte aqui.

### Diferença chave vs motoristas

Pessoa de ônibus geralmente **não pode evitar o trajeto** — quem vai pegar o último ônibus pra casa não tem opção. Produto não pode ser "evite essa rota" → tem que ajudar a **se preparar**.

### Funções planejadas (V2 maduro)

1. **"Vale a pena descer aqui?"** — Antes de descer, usuário consulta o ponto. Tela mostra relatos recentes próximos + tempo a pé até endereço final. Decisão informada: descer ali, no anterior ou no próximo.
2. **Perfil do ponto de ônibus** — Cada ponto vira nó no mapa (vêm do OpenStreetMap via Overpass). Tap mostra relatos próximos no horário, histórico, alternativas próximas (outro ponto da mesma linha 200m adiante).
3. **Risco do trecho pós-descida** — Cobre o "perigo mais real": andar do ponto até casa. Selecionando ponto + endereço, app calcula o trecho a pé e sinaliza relatos no caminho. Sugere desvio se for muito carregado.
4. **Notificação na aproximação** — Usuário tem destino salvo. Quando GPS detecta proximidade, app dispara: "Você está chegando perto do ponto Lapa. Houve 3 relatos próximos nas últimas 12h." Decisão pré-descida com tempo de reagir.
5. **"Ainda dá tempo de pegar o próximo?"** — Integra com horário GTFS municipal. Quando usuário vê movimentação suspeita no ponto, mostra "próximo ônibus em 8 min" → decide esperar dentro de comércio aberto vs no ponto exposto.

### O que NÃO fazer (cuidado editorial)

- **NÃO criar "ranking de linhas perigosas"** — toda linha que passa por periferia teria badge. Viés territorial enorme.
- **NÃO estigmatizar ponto isolado** — 1 relato num ponto não é problema do ponto, é do entorno.
- **NÃO dar veredito "não desça"** — pessoa precisa descer. Damos contexto, não decisão.

### Dados necessários (V2)

| Dado | Fonte | Disponibilidade |
|---|---|---|
| Pontos de ônibus | OpenStreetMap (Overpass) | ✅ Grátis, ~30k em Salvador |
| Linhas/rotas | GTFS da CCR Metrô / SETPS | Parcial — Salvador tem GTFS público |
| Horário em tempo real | API municipal (BUS RJ tem, Salvador parcial) | Limitado |
| Endereço final do usuário | Input no app | Privacy-sensitive — local-only |

### Que dá pra fazer já no MVP atual

Curto prazo (sem código novo): **adicionar perfil de uso "passageiro" no /sobre/** — orientar o usuário existente. Algo como:

> "Você é passageiro de ônibus? O Faro hoje ajuda você a avaliar a região do ponto onde vai descer. Use o filtro de 24h e a busca por bairro pra olhar antes de chegar."

Isso cria a expectativa correta e captura usuários desse perfil sem implementar nada novo.

### Antes de implementar V2

1. Conversar com 3-5 passageiros frequentes de Salvador (idealmente em diferentes linhas)
2. Confirmar disponibilidade dos dados GTFS de Salvador
3. Validar com transportadora local (CCR Metrô, SETPS) — pode virar parceria B2B

---

## Features de produto (UX/UI)

### Notificação por proximidade (estilo Waze)
**Peso:** alto — listado como P0 do MVP no relatório §8.1
**Status:** Implementado em 2026-05-16 (Fase 2 fechada)
**Detalhes:**
- Banner in-app `_ProximityBanner` quando há relato em raio de 1km nas últimas 6h (commit 1f88bd9).
- Push direcionado server-side via FCM topic por geohash precisão 5 + Cloud Function `proximityAlert.onOccurrenceCreated` (commit 3cfd822).
- **Background tracking (Waze-like)**: `BackgroundLocationService` abre `Geolocator.getPositionStream` com filtro de distância 500m, recalcula geohash5 a cada movimento e resubscreve o tópico FCM da nova célula. Em iOS usa `AppleSettings.allowBackgroundLocationUpdates`; em Android usa `AndroidSettings.foregroundNotificationConfig` (notif persistente exigida pelo SO).
- **Catch-up**: ao mudar de geohash5, consulta Firestore por relatos < 6h na nova célula. Se houver, dispara `LocalNotificationService` com copy editorial ("X relatos próximos a você nas últimas 6h"). Range query no campo `geohash` precisão 8 com sentinel ``.
- **Opt-in progressivo**: toggle no `/sobre/` (`_BackgroundAlertsToggle`). Pede `LocationPermission.always` + permissão de notif. Recusa preserva o comportamento foreground-only. Persiste em `SharedPreferences` (`bg_location_enabled_v1`).
- **iOS Info.plist**: `UIBackgroundModes` = `fetch`, `location`, `remote-notification`.
- **Android Manifest**: `ACCESS_BACKGROUND_LOCATION`, `FOREGROUND_SERVICE_LOCATION`, `WAKE_LOCK`, etc.
- **Bateria**: ~2-3%/h em movimento contínuo, ~0%/h parado (stream pausado por `pauseLocationUpdatesAutomatically`).
- **Testes**: `background_location_service_test.dart` cobre opt-in lifecycle e dedupe de geohash5; `local_notification_service_test.dart` cobre singleton + no-op em count≤0.

### Cluster manager (alternativa/complemento ao heatmap)
**Status:** Implementado em 2026-05-14 (custom, sem dep externa)
**Detalhes:** Entre zoom 14.5 e 17 (`_heatmapZoomThreshold` → `_clusterCeilingZoom`), agrupa por célula dimensionada pra ~80px na tela. Cluster vira badge com count + anel da cor do `RiskLevel` máximo. Tap zoom-in 2 níveis. Ícones pré-bakeados (45 = 9 strings × 5 risks) em `ClusterMarkerFactory`. Rebuild via `onCameraIdle` quando zoom muda > 0.3.

### Sistema de contestação real
**Status:** Loop completo fechado em 2026-05-20 + moderação reversa (onWrite) em 2026-05-21
**Detalhes:**
- Cliente: `ContestationScreen` com 5 motivos pré-prontos + campo livre. `ContestationService` (Riverpod) escreve em Firestore via Anonymous Auth — usuário sem cadastro mas com UID estável.
- Server: Cloud Function `onContestationWritten` (`functions/lib/contestationAggregator.js`) é disparada por **qualquer** escrita em `/contestations` (create/update/delete), agrega todas as contestações da ocorrência e grava no doc da ocorrência: `contestationCount`, `contestationDistinctUsers`, `contestationReasonBreakdown`, `contestationsLastUpdated`. Quando `distinctUsers >= 3` (threshold conservador anti-abuso, conta UIDs distintos), marca também `contested: true` e `contestedAt`. Se o agregado cair abaixo do threshold (moderador apagou contestações abusivas, usuário desfez a sua), o flag `contested` é removido com `FieldValue.delete()` — mantém o estado coerente.
- Cliente lê esses campos via `Occurrence.fromFirestore` (`contestationDistinctUsers`, `contested`) e a `OccurrenceDetailSheet` mostra um banner discreto: tom neutro abaixo do threshold, atenção visível quando contestado.
- Rules Firestore (`/contestations`) bloqueiam delete/update pelo cliente — moderação reversa fica restrita ao Console Firebase ou Admin SDK.
- 6 testes unitários na lógica pura de agregação (`functions/test/contestationAggregator.test.js`).
- **TODO V2**: expor `contestationReasonBreakdown` em uma view de moderação interna.

### Onboarding de 1 tela com aceite de termos
**Status:** Implementado em 2026-05-11 (commit 3d9950c)
**Detalhes:** `OnboardingScreen` bloqueante na 1ª abertura, aceite explícito via checkbox + `shared_preferences` persiste. Frases-âncora editoriais ("não dizemos que está seguro", "complementa atenção, não substitui").

### Modo offline com cache regional
**Status:** Implementado em 2026-05-11 (commit fc9a942)
**Detalhes:** Firestore offline persistence habilitado em `main.dart` com `cacheSizeBytes: CACHE_SIZE_UNLIMITED`. App sem sinal ainda mostra último snapshot sincronizado. Cache estruturado por região (V3) ainda TODO.

---

## Infraestrutura e processo

### Cleanup periódico de occurrences antigas
**Status:** Implementado em 2026-05-11 (commit 90050ae)
**Detalhes:** Scheduler `cleanupOccurrences` em `functions/lib/` roda diariamente, deleta docs com `expiresAt < now`. Inclui também cleanup de `news_seen` antigo.

### Backfill histórico
**Status:** Implementado em 2026-05-11 (commit 9240153) + agregação por bairro em 2026-05-21
**Detalhes:**
- `backfillFogoCruzado` (HTTP function manual) puxa histórico do Fogo Cruzado e popula `occurrences`.
- `aggregateHistoricalBaseline` (scheduler diário, `functions/lib/historicalBaseline.js`) agrupa as ocorrências dos últimos 90d por (state, city, neighborhood) e grava em `/historical_baseline/{regionKey}` com `totalOccurrences`, `weeklyAverage`, `recentWeekCount`, `trend` (up/down/stable/insufficient_data) e `topReasons`.
- Cliente: `HistoricalBaselineService` + `baselineProvider(BaselineLookup)` (Riverpod família) leem por bairro sob demanda. `AreasScreen` mostra uma linha discreta no card de cada bairro com ícone + texto editorial ("acima/abaixo/em linha com a média histórica do bairro"). Bairros com dados insuficientes ficam em silêncio.
- Trend thresholds: up se `recentWeek ≥ avg × 1.4`, down se `≤ 0.6 × avg`, stable no meio. Mínimo de 5 relatos na janela pra evitar tendência com base em ruído.
- 15 testes unitários cobrem a função pura em `functions/test/historicalBaseline.test.js`.

### Geo-hash queries no Firestore (V2)
**Status:** Server-side pronto, client-side prematuro
**Detalhes:** Campo `geohash` (precisão 8 via `ngeohash`) já é escrito em todos os 3 paths server-side (`fogoCruzadoSync`, `fogoCruzadoBackfill`, `newsIngest`). O `OccurrencesService.recent()` do app ainda usa `where date > cutoff limit(500)` — só vale migrar quando passar de ~10k docs, hoje o batch cobre Salvador com folga. Reabrir quando densidade aumentar.

### CI/CD completo
**Status:** Implementado em 2026-05-14 (commits 2c9d884, fd8bdf9)
**Cobertura atual:**
- PR: `flutter analyze` + `flutter test` (28 testes reais, suite plantada no commit 61db9ef) + Android APK debug + **iOS no-codesign**
- Main: deploy auto de Functions + Firestore rules/indexes, com **preflight de secrets** (skipa gracefully se ainda não foram configurados) e environment "production" opcional pra aprovação manual
- Actions todas em `@v5` (sem Node 20 deprecation)
**TODO:** fastlane pra TestFlight/Play Console (publicação binária) — exige Apple Developer cert + App Store Connect API key + Play Console service account.
**Setup pendente manual** (você precisa fazer):
- Secrets `FIREBASE_SERVICE_ACCOUNT` + `GCP_PROJECT_ID` no GitHub
- Environment `production` (opcional, recomendado) com required reviewer
- Passo a passo em `docs/firebase_setup.md` §12

### Crashlytics + Analytics
**Status:** Implementado em 2026-05-14 (commit a27223f + 8f02bad)
**Detalhes:** Firebase Crashlytics + Firebase Analytics. Eventos custom sem PII: `screen_view` (map, areas, search, help, about, contestation, onboarding), `occurrence_open` (entry × source × age_bucket), `filter_applied`, `max_zoom`, `proximity_alert_shown/tapped`. Retenção D1/D7/D30 auto via `session_start`. Wrapper em `app/lib/services/analytics_service.dart`. Crashes só em release (debug desligado pra não poluir métricas).
**Setup pendente manual** (você precisa fazer):
- Ativar Crashlytics no console Firebase
- Build phase "Run Script" no Xcode pra upload de dSYM (iOS) — passo a passo em `docs/firebase_setup.md` §11

---

### Inteligência semântica (embeddings + narrativas)
**Status:** Implementado em 2026-05-22 (Bloco 1-4)
**Peso editorial:** crítico — primeiro recurso onde Faro vai além de "agregador" pra ser "interpretador" de eventos relacionados.
**Detalhes:**
- **Embedding pipeline** (`functions/lib/embedClient.js`): wrapper Gemini `text-embedding-004` (768d, multilíngue, free tier 1500 RPM). REST direto sem SDK. `batchEmbedContents` cobre até 100 itens/chamada, com retry exponencial em 429/503.
- **newsIngest grava embedding** no doc da occurrence (campo `embedding` via `FieldValue.vector()`, mais `embeddingProvider` e `embeddingDim`). Falha graciosa: sem Gemini, grava sem embedding e o pipeline antigo cobre dedup.
- **Vector index** declarado em `infra/firestore.indexes.json` — `occurrences.embedding`, 768d, COSINE. Deploy via `firebase deploy --only firestore:indexes` (exige CLI ≥ 13.0).
- **Dedup semântico** (`findSemanticDuplicate` em newsIngest): `findNearest` filtrado por janela ±6h, threshold cosseno ≥ 0.88 (distance ≤ 0.12). Substitui o lookup por eventKey nos casos com embedding; eventKey continua como fallback. Resolve "mesma matéria reescrita em portais diferentes" automaticamente.
- **Backfill manual** (`backfillEmbeddings` HTTP function): one-shot, paginado, dryRun opcional. Cobre as ~287 occurrences históricas em uma chamada. Idempotente.
- **Clustering de narrativas** (`functions/lib/narrativeAggregator.js`): scheduler diário 04:00, agrupa últimos 7d por similaridade ≥ 0.80 + mesma cidade. Greedy single-link com centroide incremental — O(n²) trivial em < 1k docs. Filtro mínimo de 3 relatos por cluster. Escreve `/narratives/{citySlug__bairrosSlug}` com `headline` editorial pré-gerada (sem palavras alarmistas), top reasons, 3 samples mais recentes.
- **UI "Esta semana"** (`app/lib/widgets/narratives_strip.dart`): faixa horizontal no topo da AreasScreen, antes do TimeWindow selector. Esconde quando não há narrativas. Card de 280px com count + headline editorial. Tom: "Esta semana — 6 relatos relacionados em Garcia." Nunca veredito.
- **Rules**: `/narratives/{id}` leitura pública, escrita só Cloud Function.
- **Testes**: 24 testes novos cobrindo embedClient (8), embedBackfill (5), narrativeAggregator (11). Total Functions: 180 testes verdes.
- **Setup pendente manual** (você precisa fazer): criar API key no AI Studio, `firebase functions:secrets:set GEMINI_API_KEY`, deploy do vector index + functions, rodar backfill, esperar primeiro run do aggregator. Passo a passo em `docs/firebase_setup.md` §14.
- **TODO:** calibrar thresholds após observar dados reais (logs mostram `_vector_distance` em cada match). Estender dedup semântico pra `syncFogoCruzado` (cross-source FC↔notícia do mesmo evento). Vetor `embedding` ocupa ~3KB/doc — em escala (>50k occurrences) considerar separar pra collection paralela.

---

### Painel admin interno
**Status:** Implementado em 2026-05-22 (bloco 1+2; saúde de crons e drill-down pendentes)
**Detalhes:**
- Cloud Function `aggregateAdminMetrics` (scheduler 30min, `functions/lib/adminMetrics.js`) escreve `/admin_metrics/current` + snapshot diário em `/admin_metrics/history/daily/{YYYY-MM-DD}`. KPIs: usuários (total, anônimos, Google, novos/ativos 24h/7d via Auth listUsers), ocorrências (total via `.count()`, 24h/7d via scan, breakdown por source/state/city, contestadas, top reasons), contestações (total + ocorrências distintas contestadas), safe arrivals (24h/7d).
- Acesso gateado por custom claim `admin: true`. Firestore rules em `/admin_metrics/*` exigem `request.auth.token.admin == true`. Setup via `functions/scripts/grantAdmin.js <UID>` (uma vez).
- Cliente: `AdminMetricsService` + provider Riverpod (stream do doc). `AdminScreen` lê e renderiza cards de KPIs (sem badge/marketing — ferramenta operacional). `isAdminProvider` faz `getIdTokenResult(true)` pra refrescar o claim sem esperar TTL de 1h.
- Acesso: deep link `faro://admin` registrado em AndroidManifest (intent-filter scheme/host) e Info.plist (CFBundleURLTypes). Dep nova: `app_links: ^6.4.0`.
- 6 testes unitários cobrem a lógica pura `computeMetrics` em `functions/test/adminMetrics.test.js`.
- **TODO:** instrumentar cada Cloud Function existente pra escrever `/system_health/{jobName}` no fim (lastRunAt, lastSuccess, itemsWritten, error?, durationMs) e exibir grid verde/amarelo/vermelho no painel. Drill-down de últimas ocorrências e contestadas também pendente.
- **Setup pendente manual** (você precisa fazer): deploy de rules/functions, rodar `grantAdmin.js` com seu UID, abrir `faro://admin`. Passo a passo em `docs/firebase_setup.md` §13.

---

## Marca e legal

### Validação final do nome no INPI
**Status:** "Faro" provisório
**Detalhes:** Busca formal nas classes 9 (apps) e 42 (software). Custo ~R$ 355/classe. Em paralelo: domínio `.com.br` e `.app`, conta nas redes.

### Termos de uso + política de privacidade + RIPD
**Status:** drafts vazios em legal/
**Detalhes:** Bloqueado por parecer jurídico (Validação 4 pulada). Ver legal/README.md pra ordem de prioridade.

### Conselho editorial externo
**Status:** TODO antes do beta público
**Detalhes:** 3 pessoas (representante de direitos urbanos, pesquisador acadêmico, morador de comunidade). Mandato anual, revisão trimestral do algoritmo. Princípio editorial §7.3.
