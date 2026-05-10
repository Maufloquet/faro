# Princípios Editoriais do Mapa

Documento público. Versão exibida no app, no site e disponível para imprensa.

---

## Por que este documento existe

Em uma democracia desigual, um app que classifica regiões por risco pode reforçar preconceitos territoriais e raciais mesmo com dados corretos. Periferias têm policiamento mais intenso e portanto mais boletins — não necessariamente mais crime real.

Reconhecer isso publicamente é proteção institucional **e** dever ético. Estes princípios devem orientar cada decisão de cálculo de risco, copy e ranking exibido.

---

## Princípio 1 — Densidade de dados não é densidade de risco

Mais boletins em uma região indicam mais policiamento, mais cobertura de mídia ou mais reportes — não necessariamente mais crime real. O algoritmo de risco precisa **normalizar** por essas variáveis quando elas são identificáveis, e ser explicitamente cauteloso quando não são.

**Como aplicar:** o cálculo de risco usa baseline histórico relativo (variação sobre a média da própria região), não valor absoluto comparado entre regiões diferentes.

## Princípio 2 — Nunca afirmar segurança

A única mensagem válida quando uma região não tem relatos é **"sem relatos recentes nesta área"**, jamais "área segura". A regra vale em telas, notificações, tooltips e API B2B.

**Como aplicar:** revisão linguística obrigatória em todo copy antes de release. Lista negra de palavras: *seguro, tranquilo, sem perigo, calmo, ok pra passar*.

## Princípio 3 — Cautela onde a cobertura é fraca

Em regiões onde temos pouca densidade de fontes (sem cobertura de Fogo Cruzado, portais locais escassos, poucos usuários ativos), o app **não deve mostrar baixo risco com confiança**. A ausência de informação não é informação.

**Como aplicar:** estado visual "sem dados suficientes" é distinto de "sem relatos recentes". O usuário vê qual dos dois está olhando.

## Princípio 4 — Contestação é direito, não favor

Comerciantes, moradores e qualquer pessoa atingida por um pin de risco têm o direito de contestar publicamente. O botão de contestação é visível em cada pin, com prazo máximo de resposta de 2 horas e log público de revisões.

**Como aplicar:** workflow de moderação documentado, com responsável humano nomeado em cada turno.

## Princípio 5 — Estigmatização tem custo, e o custo é nosso

Quando um bairro inteiro é marcado como alto risco com base em poucos eventos, comerciantes locais perdem clientes e moradores sofrem com mais um rótulo público. O app reconhece esse custo e aplica threshold mínimo de fontes independentes antes de elevar uma região.

**Como aplicar:** alto risco exige N fontes independentes (≥3) corroborando dentro de janela temporal definida. Sem isso, risco máximo exibido é "moderado".

## Princípio 6 — Auditoria pública e revisão

Os dados de cálculo de risco e o histórico de revisões devem ser auditáveis por pesquisadores, jornalistas e órgãos de defesa de direitos. Conselho editorial externo (mínimo 3 pessoas, mandato anual) revisa o algoritmo trimestralmente.

**Como aplicar:** publicação trimestral de métricas agregadas: false positive rate, distribuição de risco por bairro, taxa de contestação aceita, mudanças algorítmicas no período.

---

## Conselho editorial (a constituir antes do lançamento beta)

Composição alvo:
- 1 representante de organização de direitos urbanos (ex: Instituto Igarapé, Casa Fluminense)
- 1 pesquisador acadêmico de segurança pública
- 1 representante de moradores de comunidade

Mandato anual, voto consultivo (não vinculante), reunião trimestral com publicação de ata.
