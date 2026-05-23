# Política de privacidade

**Versão 1.0 — válida a partir de 2026-05-23**

Esta política descreve quais dados o Faro coleta, como usa, e quais direitos você tem sobre eles. Em conformidade com a LGPD (Lei nº 13.709/2018).

## Princípio editorial

O Faro foi desenhado pra coletar o **mínimo possível**. Anonymous é o padrão, login é opcional, e tudo o que você preenche em "Meu perfil" é opcional. O app continua funcionando se você não preencher nada.

## 1. Que dados coletamos

### 1.1. Automáticos (sem você fazer nada)

- **Identificador anônimo** criado pelo Firebase no seu aparelho. Não vinculado a você.
- **Localização aproximada** apenas quando você ativa "Alertas por proximidade" — usamos pra inscrever seu aparelho em alertas da região, sem armazenar histórico no servidor.
- **Métricas de uso** anônimas (telas abertas, eventos como toque em ocorrência), via Firebase Analytics. Sem identificadores pessoais.
- **Logs de erros** anônimos via Firebase Crashlytics, pra corrigir bugs.

### 1.2. Opcionais (você preenche se quiser)

- **Nome de exibição**, modos de transporte que usa, horários típicos, bairro principal.
- **Localização de referência** (hotel, casa) que você decide salvar.
- **Bairros favoritos** que você marca.
- **Conta Google** se você optar por sincronizar entre dispositivos.

### 1.3. Quando você interage

- **Contestação de relato:** se você marca uma ocorrência como "imprecisa", registramos o motivo + seu identificador anônimo (sem nome). Usado pra moderação coletiva.
- **"Cheguei bem":** registrado anonimamente, agregado por bairro e dia. Não vinculado a você.

## 2. Pra que usamos

- Mostrar o mapa de ocorrências e contexto editorial.
- Mandar alertas relevantes pra você (proximidade, resumo diário se você ativar).
- Personalizar o app baseado no perfil que você preencheu.
- Melhorar o app analisando uso agregado (anônimo).

## 3. Pra quem mandamos

- **Google Cloud / Firebase:** infraestrutura de armazenamento e push notification (servidores no Brasil quando possível).
- **Groq:** modelo de IA que classifica notícias. Recebe só o **título e resumo** de matérias públicas, nunca dados seus.
- **Google AI / Gemini:** modelo de IA pra embeddings semânticos. Mesma regra — só texto público.

Não vendemos seus dados. Não compartilhamos com anunciantes. Não usamos pra publicidade.

## 4. Quanto tempo guardamos

- **Ocorrências:** 30 dias após a data do relato, então apagamos.
- **Cache de notícias vistas:** 90 dias.
- **Dados do seu perfil:** enquanto você usar o app. Você apaga a qualquer momento.
- **Análises anônimas:** prazos do Firebase Analytics (14 meses padrão).

## 5. Seus direitos (LGPD)

Você pode, a qualquer momento:

- **Acessar** seus dados — botão "Exportar meus dados" em /Sobre → Privacidade e dados.
- **Apagar** sua conta e todos os dados vinculados — botão "Apagar minha conta" na mesma tela. Irreversível.
- **Corrigir** dados em "Meu perfil".
- **Revogar consentimento** desativando notificações ou desinstalando o app.
- **Saber pra quem mandamos** — esta política lista todos.
- **Reclamar** à ANPD (autoridade brasileira de proteção de dados).

## 6. Segurança

Os dados ficam em servidores do Firebase com criptografia em trânsito e em repouso. Acesso restrito por regras (Firestore Rules) que só permitem você ler e escrever os seus próprios dados.

Não somos imunes a falhas. Em caso de vazamento, notificaremos via push e e-mail (se você tiver fornecido) dentro do prazo legal.

## 7. Crianças e adolescentes

O Faro não é destinado a menores de 18 anos.

## 8. Contato

Dúvidas, reclamações ou solicitações: **contato@faro.app** (placeholder — endereço definitivo ao final do beta).

## 9. Mudanças nesta política

Mudanças importantes serão comunicadas via push e tela inicial. Histórico de versões mantido em `legal/politica_privacidade.md` no repositório do projeto.
