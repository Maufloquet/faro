# Roadmap de Features

Banco de ideias estruturado, atualizado quando aparecem propostas que não cabem agora mas valem registro.

Status atual (sessão de 2026-05-11): MVP funcional com dados reais do Fogo Cruzado em Salvador, todos os componentes editoriais (mapa, lista, detalhe, filtros, áreas, sobre, ajuda) prontos.

---

## Camadas de dados (estende a fundação)

### Camada 2 — Scraping de portais de notícia
**Status:** em implementação
**Peso no score:** 0.3
**Detalhes:** Cloud Function periódica + Google News RSS + Groq pra extrair localização + Geocoding API. Implementação atual cobre Bahia. Expansão pra outros estados depois.

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

### Notificação por proximidade (estilo Happn)
**Peso:** alto — listado como P0 do MVP no relatório §8.1
**Status:** TODO
**Abordagem híbrida:**
- Fase 1.5: Push direcionado server-side (FCM topic por geohash precisão 5). Cloud Function publica em tópico da região quando ocorrência nova entra.
- Fase 2: Geofence client-side pra 5-10 relatos mais próximos (alerta local rápido sem servidor).

**Cuidados editoriais:** rate-limiting (máx 3 notificações/h), linguagem calibrada ("Novo relato a 200m" nunca "PERIGO!"), opt-in claro.

### Cluster manager (alternativa/complemento ao heatmap)
**Status:** TODO
**Detalhes:** Quando zoom > 14.5 mas ainda há muitos pinos amontoados, agrupar em badges com contagem. `google_maps_cluster_manager_2` ou implementação custom por geohash.

### Sistema de contestação real
**Status:** placeholder hoje (SnackBar)
**Detalhes:** Cloud Function que recebe contestação, marca o report como contestado, notifica revisão. Workflow de moderação com SLA de 2h.

### Onboarding de 1 tela com aceite de termos
**Status:** TODO
**Detalhes:** Tela única bloqueante na primeira abertura: aceite breve dos termos + 2 frases-âncora ("não dizemos que está seguro", "complementa sua atenção, não substitui"). Não onboarding multi-tela (causa abandono).

### Modo offline com cache regional
**Status:** TODO (V3)
**Detalhes:** Última versão do risk-score regional cacheada via Firestore offline persistence. Útil pra túneis, áreas sem sinal.

---

## Infraestrutura e processo

### Cleanup periódico de occurrences antigas
**Status:** TODO
**Detalhes:** Função separada que roda diariamente, deleta docs com expiresAt < now - buffer. Mantém Firestore enxuto.

### Backfill histórico
**Status:** TODO
**Detalhes:** Job único que pega históricos do Fogo Cruzado (90 dias para trás) e popula `historicalBaseline` por região. Útil pro cálculo de "tendência" (variação sobre baseline).

### Geo-hash queries no Firestore (V2)
**Status:** TODO
**Detalhes:** Quando base passar de 10k docs, queries por viewport via geohash range fica mais rápido que `where date >`. Mudar `OccurrencesService.recent()` pra também filtrar por geohash baseado em LatLngBounds do mapa.

### CI/CD completo
**Status:** parcial (analyze + test + Android build APK no push)
**TODO:** Build iOS no PR, deploy automático de Cloud Functions em main, fastlane pra TestFlight/Play Console.

### Crashlytics + Analytics
**Status:** Implementado em 2026-05-14 (falta passo manual no Xcode pra Run Script — ver `docs/firebase_setup.md` §11)
**Detalhes:** Firebase Crashlytics + Firebase Analytics. Eventos custom sem PII: `occurrence_open`, `filter_applied`, `max_zoom`, `proximity_alert_shown/tapped`. Retenção D1/D7/D30 auto via `session_start`. Wrapper em `app/lib/services/analytics_service.dart`. Crashes só em release (debug desligado pra não poluir métricas).

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
