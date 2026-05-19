# Sindicato dos Rodoviários — BA

**Objetivo:** estabelecer canal direto pra receber, em tempo real, sinais
de incidentes em ônibus/pontos/terminais — antes mesmo da imprensa.

## Por que faz sentido

- Motoristas e cobradores são **sensores em rede** distribuídos por toda
  Salvador
- Quando rola assalto, agressão ou tiroteio no ônibus, o motorista comunica
  ao sindicato **antes** de virar matéria de jornal (e muitos casos nunca
  viram matéria)
- Sindicato tem **WhatsApp interno** ativo entre delegados — onde
  circulam relatos em tempo real
- A **categoria perde** quando linhas ficam estigmatizadas pela mídia
  sem dado — eles têm interesse direto em ter ferramenta que mostre o
  contexto editorial honesto que o Faro propõe

## Sindicato-alvo

**SINDIRODOVIÁRIOS-BA** (Sindicato dos Trabalhadores Rodoviários do
Estado da Bahia)
- Site: http://www.sindirodoviariosba.com.br
- E-mail institucional: secretaria@sindirodoviariosba.com.br
- Presidente: pesquisar a cada gestão

Também relevante:
- **SETPS** (sindicato patronal de empresas de transporte) — porta
  alternativa, mas interesse menos alinhado
- **STT-Salvador** (Superintendência de Trânsito e Transporte) — órgão
  público da prefeitura

## Proposta concreta

Em troca de:
- Acesso prioritário/silencioso a um canal Telegram ou WhatsApp Business
  do Faro, onde o sindicato envia relatos imediatos
- Validação editorial do app pela diretoria (não precisa ser endorsement
  formal — só não-contestação)

O Faro entrega:
- **Boletim diário** automatizado por linha de ônibus citada no app
  (gerado pelo pipeline atual de extração editorial)
- **Dashboard público** (sem login) por linha — útil pra pauta sindical
  ("a linha X teve N incidentes nas últimas 4 semanas")
- **Disclaimer editorial fixo**: linha citada não é "linha perigosa", é
  linha referenciada em notícia. O Faro nunca recomenda evitar linha
  (princípio §7 do roadmap)

## Template do primeiro contato

> **Assunto:** Proposta de canal direto — projeto Faro / dados de
> segurança em ônibus
>
> Prezada(o) **[Presidente / Diretor de Comunicação]**,
>
> Sou **[seu nome]**, responsável pelo projeto **Faro** (em
> desenvolvimento), aplicativo gratuito que mapeia ocorrências de
> segurança em Salvador combinando dados públicos (Fogo Cruzado,
> jornais locais) e aplicando inteligência editorial.
>
> Diferente de outras ferramentas similares, o Faro **explicitamente
> evita virar lista de "linhas perigosas"** — princípio editorial
> permanente, registrado na seção "Linhas de ônibus citadas":
>
> > *Linhas mencionadas em matérias de jornal sobre relatos do período.
> > NÃO é ranking de linha perigosa — pessoa que depende da linha não
> > pode trocar. Use pra se preparar.*
>
> **Estou propondo uma colaboração específica com o Sindirodoviários:**
>
> - **Canal silencioso** em que delegados do sindicato possam encaminhar
>   relatos imediatos de incidentes em linhas/pontos/terminais — gravados
>   no Faro com **fonte "sindicato"** e prioridade editorial
> - Em contrapartida, o Faro disponibilizaria:
>   - **Boletim diário automatizado** por linha citada (insumo direto
>     pra pauta da categoria junto às empresas e à STT)
>   - **Dashboard público** por linha, sem login, com a metodologia
>     editorial transparente
>   - Atribuição "**Sindirodoviários-BA**" como fonte parceira na tela
>     "Sobre o Faro" do aplicativo
>
> Acredito que essa troca pode beneficiar tanto a categoria quanto a
> coletividade — incidentes que hoje não viram matéria ficariam
> registrados, e a narrativa pública sobre o transporte público em
> Salvador passaria a ter base mais larga que apenas a manchete.
>
> Posso apresentar o projeto pessoalmente nas próximas duas semanas, em
> reunião presencial ou virtual de 30 minutos. Anexo o link da
> documentação pública: **[URL do GitHub / docs do Faro]**
>
> Atenciosamente,
> **[Seu nome]**
> **[Telefone e e-mail]**

## Cuidados

1. **Não menciona "anti-greve" nem "compliance"** — sindicato é
   adversário institucional dessas pautas
2. **Foco em poder da categoria**, não em consumidor — "dado pra
   sustentar pauta" pega melhor que "ferramenta pro passageiro"
3. **Não pedir endorsement formal**, apenas canal silencioso. Sindicato
   não dá endosso por escrito a projeto privado sem assembleia
4. Se vier reunião, **levar protótipo rodando** — mostrar quando uma
   matéria mencionou "linha 1234" e o pin apareceu no mapa
5. **Reciprocidade tangível desde a primeira semana** — não esperar
   meses pra entregar o boletim. Mesmo um e-mail diário automático já
   é começo

## Implementação técnica (lado Faro)

Pra realmente ter canal funcional, precisa:

1. **Categoria nova de `source`** em occurrences: `'sindicato_rodoviarios_ba'`
2. **Peso editorial** mais alto que mídia (eles são testemunha direta)
3. **Forma de ingest** — opções em ordem de viabilidade:
   - Bot Telegram com username dedicado que delegados acionam
   - Formulário web super-curto (sem login) cuja URL é distribuída
     apenas aos delegados (security through obscurity inicial)
   - WhatsApp Business API depois — só vale o esforço se a parceria
     pegar
4. **Moderação editorial leve** — primeiros relatos passam por revisão
   antes de virar pin público, pra evitar uso indevido. Pode ser
   manual no início (Telegram channel privado de "review")
