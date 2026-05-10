# Visão do Produto

## Pitch em uma frase

Um app móvel que ajuda o cidadão a responder, em tempo real, **"o que está acontecendo perto de mim agora, e devo evitar passar por ali?"** — combinando dados públicos de segurança, relatos de outros usuários e sinais passivos urbanos. Sempre comunica probabilidade, **nunca certeza**.

## Problema

No Brasil, decisões cotidianas de deslocamento urbano são tomadas no escuro. Pegar uma rua à noite, deixar o carro em determinada quadra, andar até o ponto de ônibus distante mas em via mais movimentada — todas guiadas por intuição, boato em grupo de WhatsApp e medo difuso.

Apps existentes (Onde Fui Roubado, Cidadão de Bem, mapas SSP) tratam segurança como **histórico estatístico**, não como **decisão pontual em tempo real**. O usuário descobre que houve roubos no bairro semanas atrás, não que está havendo movimentação suspeita agora.

## Quem é o usuário

| Perfil | Caso de uso típico | % esperado |
|---|---|---|
| Cidadão urbano ansioso | Decidir rota a pé, conferir antes de descer do Uber | 60-70% |
| Entregador / motorista de app | Avaliar viabilidade de entrega em região desconhecida | 15-20% |
| Morador de área de risco | Acompanhar movimentação no bairro em tempo real | 10-15% |
| Profissional liberal em campo | Vendedor, técnico, agente social circulando | 5-10% |

## Posicionamento editorial — frase âncora

**"Não somos um mapa de crimes. Somos um assistente de decisão em tempo real."**

Essa distinção define cada decisão de UX, copy e modelagem de dados. Toda comunicação probabilística, nunca declarativa. A regra editorial central:

> O app **NUNCA** comunica "está seguro". A única mensagem válida é "sem relatos recentes nesta área".

## Diferenciação

| Concorrente | O que faz | O que fazemos diferente |
|---|---|---|
| Onde Fui Roubado | Mapa histórico | Tempo real + decisão pontual |
| Cidadão de Bem | Botão de pânico + rede de vizinhos | Funciona sem precisar montar rede |
| Mapas oficiais SSP | PDF mensal agregado | Granularidade de quadra, atualização contínua |
| Grupos WhatsApp de bairro | Relatos sem estrutura | Validação coletiva, expiração automática, mapa unificado |
| Waze | Otimiza tempo | Adiciona dimensão de risco à roteirização |

## Modos de uso

**Passivo (70-80% dos usuários):** abre o mapa, lê, decide. Não reporta nada. *O produto precisa ser útil para esse perfil sozinho.*

**Ativo (5-15% dos usuários):** reporta ocorrências com GPS obrigatório, confirma ou contesta relatos próximos. Reputação invisível ajusta peso dos relatos no cálculo de risco.

## Stack técnica (planejada para Fase 1+)

Flutter no frontend (mesma stack do Datestre), Firebase para banco em tempo real e auth, Cloud Functions para pipelines de ingestão, Google Maps SDK para mapa, Groq (Llama 3 70B) para classificação, Google Geocoding como fallback (com dicionário local de bairros pra reduzir custo).
