# Beta fechado — checklist de lançamento

Plano operacional pra abrir o Faro pra ~20-30 usuários reais. O app está tecnicamente pronto desde 2026-05-22; este documento cobre tudo que **não é código** entre você e o primeiro convite.

## 1. Pré-requisitos de plataforma

### Apple (iOS)

- [ ] **Apple Developer Program** ativo (US$ 99/ano). Sem isso, sem TestFlight, sem App Store.
- [ ] Conta vinculada ao `Team ID` que está em `ios/Runner.xcodeproj` (Signing & Capabilities).
- [ ] Certificado de distribuição válido + provisioning profile pro bundle id `br.com.projetoseg.projetoSeg`.
- [ ] Setup do widget (`docs/widget_setup.md` §iOS) concluído **antes** do primeiro build de TestFlight.
- [ ] App Store Connect: criar app novo
  - Nome: **Faro**
  - SKU: livre (ex.: `faro-2026`)
  - Bundle ID: `br.com.projetoseg.projetoSeg`
- [ ] App Privacy preenchido em App Store Connect (cobre LGPD + App Tracking Transparency):
  - **Coleta**: localização (precisa, opt-in), identificadores (Firebase Analytics), uso e diagnóstico (Crashlytics).
  - **Vinculação a você**: não. Tudo anônimo por design.
  - **Tracking**: não usa.

### Google (Android)

- [ ] **Google Play Console** ativo (US$ 25 taxa única). Bem mais barato que iOS.
- [ ] Criar app novo com bundle id `br.com.projetoseg.projeto_seg`.
- [ ] **Internal Testing Track**: o caminho mais rápido pra distribuir sem revisão completa do Google. Aceita até 100 testers via lista de e-mails.
- [ ] Data Safety form preenchido (equivalente Android do App Privacy).
- [ ] Política de privacidade pública obrigatória — **hospedar `legal/politica_privacidade.md` numa URL acessível**. Sugestão: criar `https://faro.app/privacidade.html` ou GitHub Pages. Sem URL pública, Play Console barra o release.

## 2. Pré-requisitos do app

- [x] Termos + Política (assets/legal/, Frente 3).
- [x] LGPD básico (exportar + apagar conta, Frente 3).
- [x] Onboarding com aceite explícito (Frente 2).
- [x] Anonymous-first, login Google opcional.
- [ ] **Versão de release configurada**:
  - `pubspec.yaml`: `version: 0.1.0+1` → bumpar pra `0.1.0+2` antes do primeiro upload, depois `+3`, `+4` por iteração.
  - `app/android/app/build.gradle`: confirmar `versionCode = flutterVersionCode` (vem do pubspec).
- [ ] **Splash + ícone**: revisar `assets/icon/` no celular do convidado (icon não pode estar a tamanho errado).
- [ ] **Run Script Xcode pra dSYM** (Crashlytics iOS) — pendente desde 2026-05-14 (ver `docs/firebase_setup.md` §11 iOS).
- [ ] **Ativar Crashlytics no console** — também pendente.
- [ ] **`GEMINI_API_KEY` no Firebase Secrets** já feito? Confirmar com `firebase functions:secrets:access GEMINI_API_KEY`.
- [ ] **`grantAdmin.js` rodado pra você** — sem isso o painel `faro://admin` mostra "acesso negado".

## 3. Build de TestFlight (iOS)

```
cd app
flutter build ipa --release
# Saída em build/ios/ipa/projeto_seg.ipa
```

Upload via Xcode (Organizer → Distribute App) ou via `xcrun altool` se tiver conta de upload. Em ~10 min, aparece em App Store Connect → TestFlight.

Convidados:
- Adicionar e-mails em **TestFlight → Testers**.
- Limite: 10.000 por release. Mais que suficiente.
- Eles recebem convite por e-mail e instalam pelo app TestFlight (gratuito na App Store).

## 4. Build de Internal Testing (Android)

```
cd app
flutter build appbundle --release
# Saída em build/app/outputs/bundle/release/app-release.aab
```

Upload pelo Play Console → Testing → Internal testing → Create new release.

Convidados:
- Adicionar e-mails em **Internal testers (lista de e-mails)**.
- Eles recebem link, instalam direto pelo Play Store.

## 5. Mensagem de convite (PT-BR)

Modelo curto pra mandar individualmente — WhatsApp, e-mail, etc:

> Oi! Tô testando um app que mostra contexto de segurança em Salvador (sem alarmismo, sem ranking de bairros — só os relatos que saem em jornal/Fogo Cruzado, organizados de forma editorial). Quero opiniões de gente real antes de abrir publicamente.
>
> Funciona em iOS e Android. Não precisa criar conta — só baixar e usar.
>
> iOS: link do TestFlight: [URL_TESTFLIGHT]
> Android: link da Play Store interna: [URL_PLAY]
>
> O que ajuda muito:
> 1. Usar 2-3 dias na rotina normal
> 2. Marcar 1-2 bairros favoritos
> 3. Me contar **qualquer coisa estranha**: contagem que não bate, bairro errado, notificação fora de hora, etc.
>
> Tem um botão "Privacidade e dados" no menu Sobre — você pode apagar tudo a qualquer momento.

## 6. Formulário de feedback

Sugestão minimalista — não pedir 30 perguntas, ninguém responde. Google Forms, 5 perguntas, 2 min:

1. **Notificações fora de hora ou fora do contexto?** [não / sim — descreva]
2. **Apareceu ocorrência em bairro errado?** [não / sim — qual?]
3. **Quantas vezes você abriu o app nos últimos 7 dias?** [0 / 1-2 / 3-5 / 6+]
4. **Resumo diário (manhã) — vale a pena?** [sim / não / não recebi]
5. **Algum medo, dúvida ou sugestão antes de a gente abrir publicamente?** [texto livre]

URL do form pode ser linkada na própria mensagem de convite + na tela `/Sobre`.

## 7. Métricas pra observar (admin panel)

Acesse via deep link `faro://admin` no seu celular após `grantAdmin.js`. Olhe a cada 2-3 dias durante o beta:

- **Usuários ativos últimos 24h** — proxy de adesão.
- **Usuários ativos últimos 7d** — proxy de retenção. Meta: retenção D7 > 30% (gate da Fase 1).
- **Saúde dos schedulers** — verde em tudo? Se algum cron tá amarelo/vermelho há mais de 1 dia, investigar antes do convidado notar.
- **Ocorrências últimos 24h por cidade** — confere que ingestão tá saudável (Salvador deve ter 5-15/dia tipicamente; zero significa que algo quebrou).
- **Contestações** — se passar de 10% das ocorrências, sinal de problema editorial.

## 8. Critérios pra abrir publicamente (sair do beta)

Ouvir os convidados, mas em paralelo medir:

- [ ] Retenção D7 ≥ 30% (gate oficial da Fase 1 no roadmap)
- [ ] Pelo menos 5 dos convidados usaram 3+ dias seguidos
- [ ] Zero crash report sério no Crashlytics nos últimos 7 dias
- [ ] Nenhum incidente de geocoding (relato em bairro errado) reportado na última semana
- [ ] INPI (Frente externa, ainda em aberto): "Faro" registrado nas classes 9 e 42 — sem isso, risco de ter que renomear se outro registrar primeiro
- [ ] Parecer jurídico sobre Termos+Privacidade (texto inicial em `assets/legal/`)
- [ ] Conselho editorial externo formado (3 pessoas) — listado no roadmap §"Marca e legal"

## 9. Plano B — se algo quebrar

- **Push diário disparando em horário errado**: desligar via Firebase Console → Functions → `dailyDigest` → Disable. Não precisa redeploy.
- **Ingestão de notícias com viés**: desligar source específica em `functions/lib/newsSources.js` setando `enabled: false` e fazer deploy só de `ingestNewsBahia`.
- **Algum cron quebrando muito**: o helper `runWithHealth` já registra. Olhar `/system_health/{jobName}` no painel admin.
- **Convidado descobriu bug crítico**: você tem o e-mail dele do TestFlight/Play. Pra mandar fix urgente, basta uploadar nova build — não precisa re-aceite.

## 10. Cronograma sugerido

| Semana | O que fazer |
|---|---|
| 1 | Apple Developer + Play Console + URLs públicas dos legais + dSYM Xcode |
| 2 | Primeiro upload pra TestFlight + Internal Track. Convidar 5 pessoas próximas (família, amigos de SSA). |
| 3-4 | Convidar mais 15-25 pessoas. Olhar admin panel a cada 2-3 dias. |
| 5 | Coletar formulário de feedback. Decidir GO/NO-GO pra V1 pública. |

Não tente convidar 30 pessoas de uma vez no dia 1 — você não vai conseguir absorver o feedback. Crescer aos poucos.
