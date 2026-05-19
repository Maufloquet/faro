# Plataforma acadêmica — Faro for Research

**Objetivo:** abrir uma API gratuita de dados do Faro pra pesquisadores
credenciados, em troca de dados de campo (entrevistas, surveys de bairro)
que enriqueçam a base. Construir um moat de longo prazo: comunidade
acadêmica que defende o app frente a crítica, processo ou regulação.

## Por que faz sentido

- Universidades brasileiras pesquisando segurança urbana **mendigam dados
  da SSP** — papers atrasados, baseados em séries de 3 anos atrás
- O Faro tem dados em tempo quase-real (T+24h via Cloud Function)
- Pesquisador entrevista vítima, faz survey em campo, coleta o que o app
  jamais teria sozinho
- Em troca de acesso, devolvem dado de qualidade altíssima + validam
  publicamente o algoritmo

Citizen (EUA) virou polêmica porque pesquisador nunca teve acesso. Faro
convida pela porta da frente.

## Universidades-alvo (ordem sugerida de aproximação)

| Instituição | Grupo de pesquisa | Por quê |
|---|---|---|
| **UFBA — ISP (Instituto de Saúde Pública)** | Núcleo de Estudos de Violência | Salvador é base. Já têm metodologia de violência urbana publicada |
| **UNEB — Cidadania, Direitos Humanos e Segurança** | Centro de Estudos Étnicos e Africanos | Lente racial-urbanística que falta no app |
| **USP — NEV (Núcleo de Estudos da Violência)** | Sérgio Adorno et al | Referência nacional. Validação acadêmica gera credibilidade |
| **UnB — NEAPP** | Núcleo de Estudos das Políticas Públicas | Política pública é cliente potencial |
| **UFRJ — IPEA / DataLab** | Daniel Cerqueira et al | Anuário de Segurança Pública vem deles |

## Contrapartida obrigatória do pesquisador

Documentar em **termo de uso**:

1. **Publicar paper em open access** (não em revista paywalled). Pode ser
   pré-print em SSRN/SciELO ou via revista com diamante open access.
2. **Compartilhar metodologia** e qualquer dado coletado em campo que
   enriqueça o Faro (anonimizado, agregado, em formato estruturado).
3. **Validar ou criticar publicamente o algoritmo** — papers que
   identifiquem viés ou erro são bem-vindos. Tem peso de auditoria.
4. **Citação obrigatória** do Faro com URL do termo de uso.

## Template do e-mail de aproximação

> **Assunto:** Acesso a dados em tempo quase-real de violência urbana —
> Faro / Salvador
>
> Prezado(a) Prof. **[Nome]**,
>
> Sou **[seu nome]**, desenvolvedor independente do projeto Faro
> (https://github.com/maufloquet/faro), um aplicativo gratuito que
> agrega dados públicos de violência urbana em Salvador e RMS — Fogo
> Cruzado, jornais locais e (em construção) Disque-Denúncia via LAI.
>
> O app é editorial, sem fins lucrativos, e adota princípio explícito de
> **não emitir veredito** sobre bairros (o disclaimer permanente em todas
> as visualizações esclarece que mais relatos ≠ mais crime real, podendo
> indicar mais policiamento e cobertura midiática).
>
> **A proposta:**
> Estou estruturando um programa chamado **Faro for Research** que
> oferece acesso gratuito a pesquisadores credenciados a:
>
> - Stream de ocorrências classificadas (geo, tipo, fonte, peso editorial)
>   com latência de ~24h
> - Histórico completo de 24 meses (no momento da abertura)
> - Anotações editoriais (contestações de relatos, agregações por bairro,
>   classificação automática por LLM)
>
> Em contrapartida, peço:
> 1. Publicação do output em **open access**
> 2. Compartilhamento de metodologia e dados de campo agregados que
>    possam enriquecer a base do Faro
> 3. Crítica/validação pública do algoritmo
>
> Acredito que o **[grupo / linha de pesquisa do prof.]** se beneficiaria
> particularmente desse acesso, e a colaboração nos faria avançar muito
> mais rápido na qualidade do produto.
>
> Posso enviar a documentação técnica e o termo de uso em rascunho para
> sua análise? Tenho disponibilidade para uma chamada de 30 min nas
> próximas duas semanas.
>
> Atenciosamente,
> **[Seu nome]**
> **[Vínculo, se houver]**
> **[E-mail e LinkedIn]**

## Implementação técnica

Mínimo viável pra começar a entregar acesso:

1. **Endpoint REST público** (`GET /api/v1/occurrences?since=...`) com:
   - Autenticação via API key emitida manualmente
   - Rate limit por chave (ex. 1000 req/dia)
   - Resposta paginada
2. **Termo de uso versionado** (PDF + Markdown) que o pesquisador assina
   antes de receber a key
3. **Página pública** `faro.app/research` listando papers publicados
   usando dados do Faro
4. **Audit log** das queries — pra detectar uso fora do escopo declarado

Custo de manutenção: baixíssimo. Cloud Function com `onRequest` lê do
Firestore (já tem), retorna JSON. Auth via Firebase Custom Tokens.

## Riscos

- **Pesquisador que não publica:** mitigação é renovação anual da key
  condicionada à entrega
- **Pesquisador que critica injustamente:** parte do contrato. Resposta
  pública à crítica é parte da reputação
- **Vazamento de dado bruto:** dados já são públicos (vindo de fontes
  públicas) — não há segredo a vazar. Termo só formaliza a cadeia
