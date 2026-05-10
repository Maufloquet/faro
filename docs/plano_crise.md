# Plano de Gestão de Crise

Documento operacional. Não é exibido publicamente, mas deve estar pronto **antes da primeira linha de código de feature** (recomendação §10 do relatório v3).

A pergunta não é se um incidente público vai acontecer. É quando.

---

## Cenários previsíveis

| Cenário | Probabilidade | Impacto | Tempo de resposta alvo |
|---|---|---|---|
| Falso alerta vira print viral no WhatsApp | Alta | Alto | 2 horas |
| Mídia noticia alerta falso causando impacto | Média | Muito alto | 4 horas |
| Comerciante processa por estigmatização | Média | Alto | 24 horas (resposta) |
| Incidente em área sem alerta no app | Alta | Muito alto | 4 horas |
| Vazamento de dados de usuários | Baixa | Crítico | 72 horas (LGPD) |
| Acusação pública de viés algorítmico | Média | Alto | 24 horas |

---

## Porta-voz

**Único, definido antes do lançamento.** Em projeto solo, é o próprio fundador.

Critério: nenhuma comunicação pública sobre o produto sai por outra fonte. Nem suporte, nem redes sociais, nem comentário em post de terceiro. Centralização garante coerência sob pressão.

## Processo de resposta — falso alerta viral

1. **Hora 0** — alerta detectado (monitoramento de menções ou contestação no app)
2. **Hora 0-1** — verificar tecnicamente: o pin existe? Quando foi criado? Quantas confirmações? Status atual?
3. **Hora 1** — remoção temporária se contestação procede; manutenção com nota de revisão se controverso
4. **Hora 2** — comunicado público: post no app + redes + email para usuários da região afetada
5. **Hora 24** — revisão pós-incidente documentada em `docs/decisoes/`

## Comunicado padrão — modelo

> Identificamos um relato em [região] que se mostrou impreciso. O pin foi removido às [hora] após contestação verificada.
>
> O app combina relatos de usuários, dados públicos e sinais automáticos. Erros acontecem — por isso temos contestação visível em cada pin e expiração automática de relatos não confirmados.
>
> Não comunicamos segurança. Comunicamos ausência de relatos recentes. Quando um relato se mostra falso, ele é removido com transparência.
>
> Para contestar qualquer pin: [link]. Para contato direto: [email].

Ajustar para tom específico de cada incidente. **Não improvisar do zero sob pressão.**

## Canal de contato público

Email de suporte real, não formulário. Resposta em 24h úteis. Localizado em rodapé visível no app e no site.

## Monitoramento de menções

Desde o dia 1 do beta:
- Menções da marca no Twitter/X
- Menções em grupos públicos do Telegram da região piloto
- Tags no Instagram
- Buscas no Google News

Ferramenta sugerida: alertas RSS + busca manual diária (caro automatizar pra projeto solo). Custo zero, 30 minutos/dia.

## Quando NÃO responder publicamente

- Reclamações isoladas sem alcance > 100 visualizações: responder no privado
- Discussões de viés algorítmico de pesquisadores: levar pro conselho editorial, responder por documento, não tweet
- Crítica genuína sobre limitação do produto: agradecer publicamente, sem defensividade

## Em caso de vazamento de dados (LGPD)

- 0-24h: contenção técnica + notificação ao DPO
- 24-72h: notificação à ANPD obrigatória
- 24-72h: notificação aos titulares afetados
- Documentação completa do incidente para auditoria posterior

Plano detalhado depende de consulta jurídica (ver `legal/`).
