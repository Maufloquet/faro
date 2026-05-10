# `infra/` — Configuração Firebase (vazio)

## O que vai aqui

Arquivos de configuração da infraestrutura Firebase:
- `firebase.json` — projetos e emuladores
- `firestore.rules` — regras de segurança
- `firestore.indexes.json` — índices compostos para queries
- `storage.rules` — se houver upload de fotos em V2
- Scripts de deploy e seed

## Quando começar

**Apenas após o gate da Fase 0 ser aprovado.**

## Por que está vazio

A modelagem de dados depende dos resultados da Fase 0 (formato dos dados de SSP, taxa de chamadas geocoding, fontes Telegram aprovadas ou não). Definir índices e rules antes de saber o modelo é retrabalho.

## Referência inicial quando autorizado

Modelo do relatório v3 (§5.3) com collections `reports`, `users`, `regions`, `confirmations`, `media_scrape`, `incidents`. Revisar contra os dados reais coletados na Fase 0 antes de implementar.
