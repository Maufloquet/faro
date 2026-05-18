# Architecture Decision Records (ADRs)

Decisões arquiteturais e estratégicas do Faro. Cada ADR documenta:
contexto, alternativas consideradas, decisão tomada e consequências.

Formato baseado em Michael Nygard (curto e direto).

## Lista

- [ADR-001 — Flutter + Firebase como stack base](001-flutter-firebase.md)
- [ADR-002 — Modo passivo na Fase 1 (sem reports diretos de usuário)](002-modo-passivo-fase1.md)
- [ADR-003 — Fogo Cruzado como fonte primária](003-fogo-cruzado-primario.md)
- [ADR-004 — Princípio editorial: nunca afirmar segurança](004-nunca-afirmar-seguranca.md)
- [ADR-005 — Escrita em occurrences só via Cloud Functions](005-escrita-via-functions.md)

## Quando criar um ADR

- Decisão estratégica que vai ser questionada no futuro
- Decisão que diverge do `docs/relatorio_v3.pdf`
- Trade-off entre opções com mérito comparável
- Mudança que afeta múltiplas camadas (app + functions + infra)

## Quando NÃO criar

- Refatoração local sem impacto arquitetural
- Decisão consensual e óbvia (escolha de lib utilitária, formatação)
- Detalhe de implementação que vive no código
