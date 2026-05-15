# Setup Firebase — passo a passo

Guia para sair do modo dev (assets locais) para dados em tempo real via Firestore + Cloud Functions.

**Tempo estimado:** 30-45 minutos. Requer billing habilitado (plano Blaze).

---

## Pré-requisitos

- Projeto GCP "faro" já criado em <https://console.cloud.google.com>
- Maps SDK Android + iOS habilitados nesse projeto
- Conta de billing vinculada ao projeto faro
- `firebase` CLI instalado e logado (`firebase --version` ≥ 15)
- `flutterfire_cli` instalado (`dart pub global activate flutterfire_cli`)

---

## 1. Criar o projeto Firebase

O projeto Firebase é uma camada em cima do projeto GCP. Como o projeto GCP "faro" já existe:

1. Acessar <https://console.firebase.google.com>
2. Clicar **"Adicionar projeto"**
3. Selecionar o projeto existente "faro" da lista
4. Confirmar habilitação do Google Analytics (recomendado — gratuito) ou pular
5. Aguardar provisionamento (~1 min)

**Resultado:** projeto Firebase faro disponível em <https://console.firebase.google.com/project/faro>.

---

## 2. Habilitar Firestore

1. No console Firebase, menu lateral → **Build → Firestore Database**
2. **Criar banco de dados**
3. Localização: **southamerica-east1 (São Paulo)** ⚠️ não tem como mudar depois
4. Modo: **Produção** (regras de segurança já estão prontas em `infra/firestore.rules`)
5. Aguardar provisionamento (~30s)

---

## 3. Habilitar Cloud Functions

1. Menu lateral → **Build → Functions**
2. Clicar em "Começar"
3. Confirmar plano Blaze (pay-as-you-go) — Cloud Functions exige billing

---

## 4. Vincular o repo local ao projeto Firebase

Da raiz do repo (`~/projetos/faro`):

```bash
firebase login          # se ainda não logou
firebase use --add      # selecionar 'faro' e dar o alias 'default'
```

Isso cria `.firebaserc` na raiz. Esse arquivo é versionado (não tem segredo).

---

## 5. Configurar secrets do Fogo Cruzado

A Cloud Function `syncFogoCruzado` precisa de email + senha do Fogo Cruzado. Não comitamos esses valores — usamos Firebase Secret Manager:

```bash
firebase functions:secrets:set FOGO_CRUZADO_EMAIL
# vai abrir editor — colar o email, salvar, fechar

firebase functions:secrets:set FOGO_CRUZADO_PASSWORD
# mesma coisa com a senha
```

Conferir:

```bash
firebase functions:secrets:access FOGO_CRUZADO_EMAIL
```

---

## 6. Deploy das regras + índices + funções

```bash
firebase deploy --only firestore:rules
firebase deploy --only firestore:indexes
firebase deploy --only functions
```

O primeiro deploy de Functions demora 3-5 min (build do código no Cloud Build).

**Verificação:**
- Funções listadas em <https://console.firebase.google.com/project/faro/functions>
- `syncFogoCruzado` deve aparecer como **agendada** (a cada 30min)

---

## 7. Gerar firebase_options.dart pro app Flutter

```bash
cd ~/projetos/faro/app
flutterfire configure --project=faro
```

Vai perguntar quais plataformas (selecionar Android e iOS) e atualizar `lib/firebase_options.dart` com os IDs reais.

---

## 8. Trocar do modo dev pra real

Editar `~/projetos/faro/app/lib/main.dart`:

```dart
// de:
const bool kUseDevAssetData = bool.fromEnvironment('USE_DEV_DATA', defaultValue: true);

// pra:
const bool kUseDevAssetData = bool.fromEnvironment('USE_DEV_DATA', defaultValue: false);
```

Ou rodar com:

```bash
flutter run --dart-define=USE_DEV_DATA=false
```

---

## 9. Forçar primeiro sync

A função `syncFogoCruzado` roda a cada 30 minutos automaticamente. Pra ter dados imediatos:

```bash
firebase functions:shell
> syncFogoCruzado()
```

Ou via console: <https://console.firebase.google.com/project/faro/functions> → 3 pontos na função → "Executar agora".

Aguardar log de "Sync BA: N ocorrências" no `firebase functions:log`. Conferir Firestore: deve ter docs em `occurrences/`.

---

## 10. Verificar fim a fim

1. Rodar o app: `flutter run --dart-define=USE_DEV_DATA=false`
2. Mapa deve carregar com ocorrências do Firestore (não dos assets)
3. Footer mostra "Último relato há Xmin" (recente, vindo do sync real)

---

## Troubleshooting

**Função roda mas não grava nada**
- Conferir secrets: `firebase functions:secrets:access FOGO_CRUZADO_EMAIL`
- Conferir logs: `firebase functions:log --only syncFogoCruzado`

**App reclama de plataforma não suportada**
- `flutterfire configure` não rodou ou rodou parcial — repetir e selecionar Android+iOS

**Mapa branco**
- Maps SDK não habilitado pra essa plataforma OU chave restrita errada
- Conferir Cloud Console → APIs e serviços → Credenciais

**Custo está disparando**
- A Cloud Function só roda a cada 30 min, custo mensal estimado < R$ 50 com 1k usuários
- Se subiu muito, verificar se não tem outro caller forçando syncFogoCruzado em loop

---

## 11. Crashlytics + Analytics

O app loga crashes (release) e eventos editoriais de uso (sem PII).

### Habilitar no console

1. <https://console.firebase.google.com/project/faro/crashlytics> → **Ativar Crashlytics**
2. <https://console.firebase.google.com/project/faro/analytics> → confirmar que Analytics está ativo (foi habilitado no passo 1 se você marcou)

### Android

Já configurado em `app/android/`:
- Plugin `com.google.firebase.crashlytics` v3.0.2 no `settings.gradle.kts`
- Aplicado em `app/build.gradle.kts`

Nada a fazer manualmente. Build release sobe os symbols automaticamente.

### iOS (Run Script — obrigatório)

Crashlytics no iOS precisa de uma build phase que sobe os dSYMs após cada compilação. **Tem que abrir o Xcode pra fazer isso uma vez:**

1. Abrir `app/ios/Runner.xcworkspace` no Xcode
2. Selecionar target **Runner** → aba **Build Phases**
3. Clicar **+ → New Run Script Phase**
4. Renomear pra **Firebase Crashlytics Upload Symbols**
5. Em "Run only when installing", deixar **desmarcado**
6. No script, colar:

```bash
"${PODS_ROOT}/FirebaseCrashlytics/run"
```

7. Em "Input Files" (importante pro Xcode 15+):

```
${DWARF_DSYM_FOLDER_PATH}/${DWARF_DSYM_FILE_NAME}/Contents/Resources/DWARF/${TARGET_NAME}
$(SRCROOT)/$(BUILT_PRODUCTS_DIR)/$(INFOPLIST_PATH)
```

8. Salvar (⌘S), fechar Xcode.

### Verificar que funciona

**Crashlytics** (precisa ser **release** — em debug a coleta é desligada):

```bash
flutter run --release
# no app, gerar um crash de teste: alguma tela com botão que chama
# FirebaseCrashlytics.instance.crash() temporariamente.
```

Crash aparece no painel em ~5 min: <https://console.firebase.google.com/project/faro/crashlytics>.

**Analytics** (também só em release):

DebugView (live): no painel Analytics → Debug View. Pra forçar device aparecer:

```bash
# Android
adb shell setprop debug.firebase.analytics.app br.com.projetoseg.projeto_seg

# iOS
# adicionar -FIRDebugEnabled nos argumentos de execução do Xcode
```

### Eventos custom registrados

Definidos em `app/lib/services/analytics_service.dart`. **Sem PII** — sem coordenadas, sem IDs, sem texto livre:

| Evento | Quando | Parâmetros |
|---|---|---|
| `screen_view` | Entrada em tela (map, areas, search, help, about, contestation, onboarding) | `screen_name` |
| `occurrence_open` | Usuário abre detalhe de relato | `entry` (marker\|list\|proximity_banner), `source`, `age_bucket` |
| `filter_applied` | Chip de tempo ou motivo tocado | `kind` (time_window\|reason), `value` opcional |
| `max_zoom` | Novo zoom máximo da sessão | `zoom` (arredondado) |
| `proximity_alert_shown` | Banner de proximidade aparece | `count` (clamp 1-50) |
| `proximity_alert_tapped` | Usuário toca o banner | — |

Retenção D1/D7/D30 é calculada automaticamente pelo Firebase Analytics a partir do `session_start` (não precisa logar nada).

---

## 12. CI/CD (GitHub Actions)

Dois workflows em `.github/workflows/`:

| Workflow | Trigger | O que faz |
|---|---|---|
| `flutter.yml` | PR ou push em `app/**` | `flutter analyze`, `flutter test`, build APK debug (ubuntu), build iOS no-codesign (macos) |
| `functions-deploy.yml` | Push em `main` tocando `functions/**`, `infra/firestore.*`, ou `firebase.json` | Deploy Functions + Firestore rules/indexes |

### Setup do deploy automático

O deploy precisa de dois secrets no repo. Settings → Secrets and variables → Actions → New repository secret:

#### 1. `FIREBASE_SERVICE_ACCOUNT` (JSON inteiro)

Gerar service account com escopos mínimos pra deploy:

```bash
# Substituir <PROJECT_ID> pelo ID real (provavelmente "faro")
gcloud iam service-accounts create faro-deploy \
  --display-name "Faro CI deploy" \
  --project <PROJECT_ID>

# Permissões mínimas pra deploy de functions + firestore rules/indexes:
for role in \
  roles/firebase.admin \
  roles/cloudfunctions.admin \
  roles/iam.serviceAccountUser \
  roles/artifactregistry.writer \
  roles/cloudbuild.builds.builder
do
  gcloud projects add-iam-policy-binding <PROJECT_ID> \
    --member="serviceAccount:faro-deploy@<PROJECT_ID>.iam.gserviceaccount.com" \
    --role="$role"
done

# Baixar a chave JSON
gcloud iam service-accounts keys create faro-deploy.json \
  --iam-account faro-deploy@<PROJECT_ID>.iam.gserviceaccount.com
```

Copiar o **conteúdo inteiro** do arquivo `faro-deploy.json` e colar no secret `FIREBASE_SERVICE_ACCOUNT`. Depois **deletar o JSON local** (`rm faro-deploy.json`) — ele não precisa ficar no disco.

#### 2. `GCP_PROJECT_ID`

O ID do projeto Firebase/GCP (provavelmente `faro`).

#### 3. Environment "production" (opcional mas recomendado)

Settings → Environments → New environment → `production`. Configurar:
- **Required reviewers:** seu user. Garante que cada deploy passa por aprovação manual antes de rodar.
- **Deployment branches:** só `main`.

Sem esse environment o secret precisa ser repository-wide e qualquer PR malicioso poderia tentar usá-lo.

### Verificar que funciona

1. Push trivial em `functions/` (ex: comentário no `index.js`)
2. Aba Actions do repo → workflow "Deploy Functions" deve aparecer
3. Se environment estiver configurado, vai pedir aprovação
4. Após aprovar, deve rodar 3-5 min e terminar verde
5. `firebase functions:log` mostra as funções deployadas

### Troubleshooting

**"Permission denied on functions deploy"**
- Service account não tem `roles/cloudfunctions.admin` ou `roles/iam.serviceAccountUser`
- Reaplicar o for-loop acima

**"Failed to authenticate"**
- JSON do secret pode estar mal copiado (faltando newline final, aspas extras)
- Re-criar o secret colando direto do `cat faro-deploy.json` no clipboard

**"Build iOS falha por pod install"**
- Cache do CocoaPods pode estar bagunçado. No workflow `flutter.yml` job `build-ios`, adicionar passo `cd ios && pod repo update` antes do build (deixei fora por padrão pra economizar tempo de runner — só inclui se quebrar)
