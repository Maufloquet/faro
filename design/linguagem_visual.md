# Linguagem Visual de Incerteza

Baseado em §8.1 do relatório v3. Define a paleta de risco e o vocabulário exibido em cada estado.

---

## Princípio

O app **nunca** comunica certeza. A linguagem visual e textual reforça incerteza calibrada:
- Sem verde puro
- Sem palavras absolutas ("seguro", "perigoso", "tranquilo")
- Toda comunicação probabilística e decisória

## Tabela de estados

| Estado | Cor | Texto exibido |
|---|---|---|
| Sem dados suficientes | Cinza neutro `#A8A8A0` | "Sem dados suficientes nesta região" |
| Sem relatos recentes | Cinza-azulado `#7E8C9A` | "Sem relatos nas últimas 24h" |
| Atividade leve | Bege-amarelado `#C9A65A` | "Relatos esparsos. Atenção." |
| Atividade confirmada | Laranja queimado `#C46A2C` | "Relatos confirmados. Avaliar rota alternativa." |
| Alto risco corroborado | Vermelho terroso `#9A3C2C` | "Múltiplos relatos. Evitar se possível." |

**Cores aproximadas** — refinar com designer ou validar contraste WCAG AA antes do MVP.

## Distinção crítica entre dois estados cinzas

Há dois estados que parecem similares e são tecnicamente diferentes:

- **"Sem dados suficientes"** → o app não tem fontes ativas ou histórico naquela região. **Não é informação**.
- **"Sem relatos nas últimas 24h"** → o app tem cobertura ativa naquela região e nada foi reportado no período. **É informação parcial**.

A diferença visual entre os dois precisa ser perceptível. O usuário precisa saber qual dos dois está olhando.

## Vocabulário proibido (lista negra)

Em copy, notificação, tooltip, push, email, redes sociais e API B2B:

- "seguro", "segura", "segurança garantida"
- "tranquilo", "tranquila"
- "sem perigo"
- "calmo", "calma"
- "ok pra passar"
- "rota segura" (mesmo no nome de feature)
- "vai estar tudo bem"
- "área liberada"

## Vocabulário preferido

- "sem relatos recentes"
- "atenção"
- "evite se possível"
- "rota alternativa recomendada"
- "múltiplos relatos"
- "dados insuficientes"

## Tipografia (provisória)

Coerente com a abordagem editorial do Datestre (Georgia para hero, Helvetica/Inter para corpo). A definir em wireframes.

## Notificações push

Nunca alarmistas. Sempre identificam fonte e oferecem ação:

| Bom | Ruim |
|---|---|
| "Novo relato a 200m de você" | "PERIGO na sua área" |
| "Relatos próximos confirmados" | "ATENÇÃO!! ASSALTO" |
| "Atividade incomum no seu bairro" | "Cuidado! Crime acontecendo" |

## Wireframes

A produzir em `wireframes/` antes da Fase 1. Telas mínimas:
- Mapa principal com gradação de risco
- Pin individual com estado, evidência e botão de contestação
- Onboarding de 1 tela
- Tela de reporte (2 toques)
- Tela de confirmação/contestação
