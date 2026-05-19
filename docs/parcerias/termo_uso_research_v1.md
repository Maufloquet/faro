# Termo de Uso — Faro for Research v1

**Versão:** 1.0
**Vigência:** 12 meses a partir da emissão da chave (renovável)
**Última revisão:** 2026-05

## 1. Objeto

O Faro concede ao **Pesquisador credenciado** uma chave de API que dá
acesso de leitura aos dados agregados de ocorrências de segurança
urbana mantidos pelo projeto, através do endpoint público:

```
GET https://us-central1-faro-f3472.cloudfunctions.net/getOccurrences
```

Os dados são derivados de **fontes públicas** (mídia em geral, Fogo
Cruzado, OpenStreetMap Notes) — não há informação pessoal ou sigilosa.

## 2. Contrapartidas obrigatórias do Pesquisador

Ao receber e usar a chave, o Pesquisador se compromete a:

### 2.1 Publicação em open access
Qualquer artigo, dissertação ou relatório produzido com dados do Faro
deve ser publicado em **acesso aberto** (open access) — incluindo:
- Pré-print em repositório público (SSRN, SciELO Preprints, arXiv)
- Periódico com modelo diamond/gold open access
- Repositório institucional da universidade

Publicações em revistas paywalled (Elsevier paid, etc.) sem cópia em
acesso aberto **violam o termo** e revogam a chave.

### 2.2 Compartilhamento de metodologia e dados de campo
Pesquisador que coletou dados em campo (entrevistas, surveys, observação)
e os usou em conjunto com o Faro deve **devolver versão anonimizada e
agregada** desses dados ao projeto, em formato estruturado (CSV/JSON),
junto com a documentação metodológica.

### 2.3 Crítica/validação pública do algoritmo
O Pesquisador pode (e é encorajado a) criticar publicamente o algoritmo,
metodologia ou viés do Faro. Críticas honestas e fundamentadas são bem-
-vindas — fazem parte do programa.

### 2.4 Citação
Toda publicação que use dados do Faro deve incluir:

> Dados extraídos do projeto Faro (https://github.com/maufloquet/faro),
> versão de [data do acesso]. Termos de uso disponíveis em
> docs/parcerias/termo_uso_research_v1.md.

## 3. Limites técnicos

| Tier | Requests/dia | Concurrent | Histórico |
|---|---|---|---|
| `research` (padrão) | 1.000 | 5 | 24 meses |
| `partner` (parceria formal) | 10.000 | 20 | Completo |

A chave é vinculada ao Pesquisador individual ou ao grupo de pesquisa
formalmente identificado (CNPJ ou e-mail institucional `.edu.br`).

## 4. Cláusulas de revogação

A chave pode ser revogada unilateralmente pelo Faro nos seguintes casos:

1. **Não publicação** em 24 meses após o primeiro acesso significativo
   (>100 requests)
2. **Uso fora do escopo declarado** (ex.: revender dados a terceiros,
   usar em produto comercial sem licença separada)
3. **Quebra de anonimização** (re-identificação de pessoas/vítimas)
4. **Solicitação do Pesquisador** (descontinuação voluntária)

## 5. Garantias e responsabilidades

O Faro fornece os dados **"como está"**:
- Não garante exatidão temporal ou geográfica
- Não garante exaustividade (sub-notificação é inerente à fonte)
- Não se responsabiliza por decisões tomadas com base nos dados

O Pesquisador é o único responsável por:
- Validar os dados antes de usá-los
- Cumprir as normas éticas de sua instituição (CEP/CONEP)
- Cumprir a LGPD em qualquer cruzamento com dados próprios

## 6. Versionamento

Este termo é **v1.0**. Atualizações materiais geram nova versão
(v2, v3) e disparam aceite explícito do Pesquisador. Pequenas correções
de redação ficam dentro da mesma versão.

## 7. Aceite

A chave de API é entregue **após** o Pesquisador enviar e-mail
explícito ao projeto declarando:

> Eu, [Nome completo], do grupo de pesquisa [Grupo/Instituição],
> aceito os termos da versão 1.0 do "Termo de Uso — Faro for Research"
> e me comprometo com as contrapartidas descritas na seção 2.

## Como solicitar acesso

1. Envie e-mail pra **mauriciofloquet23@gmail.com** com:
   - Seu nome completo e vínculo institucional
   - Plano de pesquisa em até 1 página
   - Aceite explícito deste termo (texto da seção 7)
2. Após análise (até 7 dias úteis), você recebe sua chave por canal
   seguro
3. Acesso renovável a cada 12 meses, condicionado ao cumprimento das
   contrapartidas
