# Widget de tela inicial — setup manual

A Frente 6 do plano introduziu um widget de tela inicial pro Faro. O Flutter cuida da sincronização de dados; cada plataforma tem código nativo próprio. Android já está plug-and-play após o build; iOS exige uma configuração manual no Xcode (uma vez, na sua máquina).

## Android — pronto

O widget Android é registrado via `AndroidManifest.xml` e roda automaticamente. Pra testar:

1. `flutter run -d <android-device>` ou build de release
2. Toque longo na tela inicial → "Widgets" → procura "Faro"
3. Arraste pra home

Atualização: o sistema chama o widget a cada 30 min. O app dispara reload sempre que muda o perfil ou chegam ocorrências novas.

Caso seu bairro principal não esteja preenchido em "Meu perfil", o widget mostra "Defina seu bairro principal no app".

## iOS — passos manuais no Xcode

Os arquivos Swift já estão prontos em `app/ios/FaroWidget/`. Você precisa adicionar a target ao projeto Xcode (uma vez):

1. Abra `app/ios/Runner.xcworkspace` no Xcode.
2. `File → New → Target → Widget Extension`
   - Product Name: **FaroWidget**
   - Bundle Identifier: **br.com.projetoseg.projetoSeg.FaroWidget**
   - Include Configuration Intent: **NO**
   - Activate scheme: **NO**
3. Quando perguntar "Activate `FaroWidget` scheme?", clique **Cancel**.
4. Xcode vai criar uma pasta `FaroWidget/` com 2-3 arquivos `.swift` e um `Info.plist`. **Apague todos esses arquivos gerados** (mande pra Trash, não só "Remove Reference").
5. No painel esquerdo, com o target `FaroWidget` selecionado, vá em `File → Add Files to "Runner"…` e adicione TODOS os arquivos de `ios/FaroWidget/`:
   - `FaroWidget.swift`
   - `FaroWidgetEntryView.swift`
   - `Info.plist`
   - `FaroWidget.entitlements`
   
   Importante: na hora de adicionar, em "Targets" só marque **FaroWidget** (desmarque Runner).
6. Em "Signing & Capabilities" do target FaroWidget:
   - Confirme o Team correto.
   - `+ Capability → App Groups` → adicionar `group.com.faro.faro`.
7. Em "Signing & Capabilities" do target Runner:
   - `+ Capability → App Groups` → adicionar a MESMA `group.com.faro.faro`. Isso é o que permite o app e o widget compartilharem dados via UserDefaults.
8. Build & Run no esquema `Runner` (cmd+R). Após instalar, vá pra tela inicial → toque longo → "+" → procura "Faro".

### Diagnóstico iOS

- Widget mostra "—" e mensagem genérica: o app ainda não escreveu dados no App Group. Abra o app, vá em "Meu perfil", defina um bairro principal e force a leitura abrindo o mapa por alguns segundos.
- Widget não aparece na lista do "+": o target FaroWidget não foi adicionado corretamente. Confira se aparece no esquema `Build → Targets`.
- Build erro "No such module 'WidgetKit'": o target FaroWidget está com `Deployment Target` muito antigo. Mude pra iOS 14.0+.

## Como o dado flui

```
Flutter app
  └── HomeWidgetService.updateWidget()
       └── HomeWidget.saveWidgetData (count, label, updatedAt)
            ├── Android: SharedPreferences cross-process
            │   └── FaroWidgetProvider.onUpdate lê e renderiza
            └── iOS: UserDefaults(suiteName: "group.com.faro.faro")
                └── FaroProvider.getTimeline lê e renderiza
```

Sem rede própria do widget. Sem PII além do nome do bairro que o próprio usuário definiu. Compatível com o princípio editorial do app.
