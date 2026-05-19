# Pedido LAI — SSP-BA / Disque-Denúncia

**Objetivo:** obter granularidade bairro/dia de boletins de denúncia anônima
(Disque-Denúncia) na Bahia, especialmente Salvador e RMS, pra alimentar o
Faro como fonte de dados complementar às matérias de jornal.

## Por que LAI

A SSP-BA publica dados agregados em painéis mensais, mas a granularidade
útil pro Faro (bairro/dia/tipo) só sai via pedido formal. **Lei Federal
nº 12.527/2011** garante acesso a dados administrativos não-sigilosos —
o que inclui boletins de denúncia anonimizados.

Caminho oficial:
- Estadual: **SIC-BA** → https://www.sic.ba.gov.br
- Federal (alternativa): **Plataforma Integrada de Acesso à Informação** → https://falabr.cgu.gov.br

Resposta legal em até **20 dias úteis** (prorrogável por mais 10).

## Template do pedido

> **Assunto:** Pedido de acesso a dados agregados do Disque-Denúncia / SSP-BA
>
> **Órgão destinatário:** Secretaria de Segurança Pública do Estado da Bahia
>
> Prezados,
>
> Com base na **Lei nº 12.527/2011 (LAI)**, solicito acesso aos seguintes
> dados administrativos do Disque-Denúncia (181) e da Ouvidoria da SSP-BA:
>
> 1. **Volume de denúncias por bairro, por dia, por tipo de ocorrência**
>    (roubo, tráfico, agressão, sequestro, tiroteio etc.), referentes ao
>    período de **[hoje - 12 meses]** a **[hoje]**, **somente para os
>    municípios de Salvador, Camaçari, Lauro de Freitas e Simões Filho**.
>
> 2. Os dados devem ser **anonimizados** (sem qualquer informação pessoal
>    identificável do denunciante ou da vítima), em formato **CSV ou JSON
>    estruturado**, com as colunas:
>    - data (YYYY-MM-DD)
>    - bairro (nome textual)
>    - município
>    - tipo da denúncia (categoria padronizada da SSP)
>    - contagem
>
> 3. **Atualização periódica:** havendo viabilidade técnica, gostaria de
>    estabelecer uma rotina de **atualização semanal ou mensal** desses
>    dados via API pública ou e-mail automático, de forma a viabilizar o
>    uso contínuo em projeto de utilidade pública (descrito abaixo).
>
> **Finalidade do uso:** os dados serão utilizados em projeto de utilidade
> pública chamado **Faro** — aplicativo gratuito, sem cadastro, que mostra
> ao cidadão o contexto de segurança em sua região em tempo real,
> combinando fontes públicas e jornalísticas. **Não é mapa de crimes nem
> ranking de bairros perigosos** — o app explicita ao usuário que mais
> relatos numa região podem indicar mais policiamento e mais cobertura,
> não mais crime real. Toda a metodologia é pública e auditável.
>
> **Tratamento de dados pessoais:** o projeto **não armazena qualquer dado
> nominal de cidadãos**. Os dados solicitados serão usados apenas em sua
> forma agregada (contagem por bairro/dia), em conformidade com a LGPD.
>
> Solicito que, na resposta:
> - Caso o pedido seja deferido, sejam indicados o **canal de entrega**
>   dos dados e o **prazo de disponibilização**.
> - Caso indeferido, sejam apresentados os fundamentos legais específicos
>   conforme art. 11 da LAI.
>
> Atenciosamente,
> **[Seu nome completo]**
> **[CPF]**
> **[E-mail de contato]**

## Cuidados práticos

1. **Não menciona "mapa de crimes"** no pedido — termo aciona reflexo
   defensivo em órgão de segurança. Use "contexto de segurança",
   "indicador agregado", "utilidade pública".

2. **Cite LGPD voluntariamente** — antecipa a objeção mais comum e
   mostra que você conhece o terreno.

3. **Limita escopo geográfico** (4 cidades) e temporal (12 meses) — pedido
   universal "todos os dados" tende a ser rejeitado por inviabilidade.

4. **Salva o protocolo** — todo pedido LAI gera nº de protocolo. Anota.
   Se passar de 20 dias úteis sem resposta, cabe recurso à autoridade
   superior (Controladoria-Geral do Estado).

5. **Acompanha pelo SIC-BA logado** — não confia em e-mail.

## Se for negado

Recurso em até 10 dias após a resposta negativa, fundamentando que:
- Dados agregados não são sigilosos (art. 23 da LAI lista taxativamente
  o que é sigiloso)
- Anonimização afasta qualquer alegação de proteção de dados pessoais
- Finalidade de utilidade pública

Se negar de novo, recurso à **CGE-BA** e, em última instância,
**Tribunal de Justiça**.

## Plano B

Enquanto LAI tramita:
- **Painéis públicos SSP-BA** (https://www.ssp.ba.gov.br/transparencia/)
  têm dados mensais agregados — não atendem granularidade desejada mas
  servem pra contexto histórico
- **Anuário Brasileiro de Segurança Pública** (FBSP) — dados anuais por
  município, calibração macro
