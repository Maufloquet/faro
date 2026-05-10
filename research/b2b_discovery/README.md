# Conversa Exploratória B2B

## Objetivo

Validar se existe disposição concreta de pagamento por um serviço de inteligência de risco urbano em pelo menos um cliente B2B potencial, antes de comprometer 12-18 meses de desenvolvimento B2C.

## Por que importa

O relatório v3 (§10 e §12) defende que B2B é a tese de receita defensável, e que premium B2C não paga a infra. Se nenhum dos clientes potenciais entrevistados demonstrar dor real e disposição de pagar, o caminho B2B-first também não funciona — o projeto deve ser arquivado.

## Critério de aprovação

**Mínimo:** 1 de 3 clientes entrevistados demonstra disposição **concreta** de pagar.

Disposição concreta significa:
- "Sim, eu pagaria R$ X/mês por isso, se entregasse Y" — com X e Y nomeados
- Ou: "Manda proposta com [escopo específico] que avalio em [prazo]"

Disposição **não-concreta** (não conta):
- "Interessante"
- "Vou pensar"
- "Manda material"
- "Quem sabe no futuro"

## Os 3 perfis a entrevistar

### Cliente 1 — Empresa local de delivery

Empresa de delivery de porte médio em Salvador (não iFood/99). Operação concentrada em uma cidade. Capacidade de decisão rápida.

Candidatos prováveis:
- Aiqfome (presente em Salvador)
- Empresas locais independentes (procurar via Google + redes)
- Cooperativas de entregadores

### Cliente 2 — Empresa de logística / última milha

Empresa que faz última milha para e-commerce em Salvador. Dor concreta com sinistros e seguros.

Candidatos prováveis:
- Loggi (parceiros locais)
- Total Express (operação local)
- Transportadoras independentes médias

### Cliente 3 — Seguradora ou plataforma de mobilidade

Seguradora de moto-frete ou plataforma local de mobilidade. Dor concreta com precificação de risco.

Candidatos prováveis:
- Buser (segmento intermunicipal)
- Seguradoras de moto especializadas (Mottu seguros, etc)
- Cooperativas de moto-fretistas

## Roteiro de conversa (30 minutos)

### Apresentação (3 min)

"Estou validando uma ideia de produto de inteligência de risco urbano em tempo real. Não estou vendendo nada hoje, só quero entender se existe dor real."

### Diagnóstico de dor (10 min)

- Como vocês decidem hoje quando uma rota é arriscada?
- Quantos sinistros (roubo, perda de carga, ferimento de entregador) por mês?
- Custo total mensal de sinistros + reposição + seguro?
- Vocês já tentaram alguma solução nessa frente? Qual foi o resultado?

### Apresentação da ideia (5 min)

Descrever em 2 minutos: API que recebe lat/lng + horário e devolve score de risco em tempo real, baseado em dados públicos + sinais comportamentais. Mostrar cenários de uso concretos (roteirização, alerta para entregador, precificação de seguro).

### Validação de pagamento (10 min)

- Isso resolveria a dor que vocês descreveram?
- Quanto custa hoje pra vocês NÃO ter essa informação? (em R$/mês)
- Se eu entregasse [escopo mínimo], qual seria a faixa de preço aceitável?
- Quem decide a contratação? Qual o ciclo de decisão?
- Topariam ser cliente piloto? (não compromisso, só sinalização)

### Encerramento (2 min)

- O que mais eu deveria estar perguntando que não perguntei?
- Posso voltar daqui a 30 dias com uma proposta concreta? (gating sem comprometer)

## Como conseguir as conversas

- Indicação via rede pessoal (sempre primeiro)
- LinkedIn — abordar gestor de operações (não CEO direto)
- Cold email com ângulo de pesquisa, não venda
- Eventos locais de logística e e-commerce em Salvador

## Documentação por entrevista

Em `samples/<empresa>_entrevista.md`:
- Data, empresa, cargo do entrevistado
- Resumo da dor relatada (3-5 bullets)
- Resposta direta sobre disposição de pagamento (frase exata)
- Próximos passos (se houver)
- Classificação: positivo concreto / positivo vago / negativo / inconclusivo

## Tempo estimado

2 semanas para conseguir e realizar 3 conversas.

## Status

TODO — não iniciado.
