# Infraestrutura Firebase

Configurações declarativas usadas pelo Firebase CLI no deploy.

## Arquivos

- `firestore.rules` — regras de segurança do Firestore. Por padrão, leitura pública de `occurrences` e `regions`; escrita só via Cloud Functions (admin SDK). User profiles isolados por uid. Tudo o que não estiver mapeado é fechado.
- `firestore.indexes.json` — índices compostos para queries por estado+date, cidade+date e geohash+date.

## Como usar

A configuração principal mora em `../firebase.json` na raiz do projeto. Os comandos abaixo rodam dali.

```bash
# Da raiz do projeto:
firebase login
firebase use --add  # selecionar projeto Firebase criado no Console

# Deploy só das regras
firebase deploy --only firestore:rules

# Deploy de tudo (regras + funções)
firebase deploy

# Emular localmente
firebase emulators:start
```

## Pré-requisitos antes do primeiro deploy

1. Criar projeto no Firebase Console (https://console.firebase.google.com)
2. Habilitar Firestore (modo nativo) e Cloud Functions
3. Plano Blaze (Cloud Functions exige billing)
4. `firebase use --add` para conectar este repo ao projeto remoto
5. Configurar secrets para o sync do Fogo Cruzado:

```bash
firebase functions:secrets:set FOGO_CRUZADO_EMAIL
firebase functions:secrets:set FOGO_CRUZADO_PASSWORD
```

## Modelo de dados (referência rápida)

Detalhe completo em `../docs/visao.md` e relatório v3 §5.3.

| Collection | Leitura | Escrita | Notas |
|---|---|---|---|
| `occurrences` | pública | Cloud Functions | uma doc por ocorrência (Fogo Cruzado, scraping etc) |
| `reports` | bloqueada | bloqueada | placeholder V2 (UGC) |
| `users` | apenas owner | apenas owner | perfil + reputação |
| `regions` | pública | Cloud Functions | score agregado por área |
