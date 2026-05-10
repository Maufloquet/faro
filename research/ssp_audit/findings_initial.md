# Auditoria SSP — Pesquisa Inicial (não-exaustiva)

Mapeamento preliminar de fontes públicas por estado. **Não é o relatório final** — é o ponto de partida para a auditoria detalhada (formato, granularidade, amostra real).

---

## Bahia — SSP-BA + Transparência BA

### Fontes identificadas

- **Transparência Bahia — Painel Estatístico de Segurança Pública**
  <https://www.transparencia.ba.gov.br/PainelEstatisticoSegurancaPublica>
  Painel construído pelo SEI DataLab em parceria com SSP-BA. Crimes contra vida e patrimônio.

- **Publicações — SSP-BA**
  <https://www.ba.gov.br/ssp/publicacoes/Estatística>
  Provavelmente PDFs mensais agregados.

### Hipóteses a verificar

- Granularidade do painel (município? bairro?). **Painel ≠ dados abertos** — verificar se há export CSV/JSON ou apenas visualização.
- Existe API ou só PDF/painel?
- Frequência de atualização real

### Próximos passos

1. Abrir o painel e mapear filtros disponíveis
2. Inspecionar requests de rede para descobrir endpoints internos
3. Procurar página "dados abertos" ou "microdados" no portal SSP-BA
4. Se não houver dados estruturados, descartar Salvador como piloto inicial

---

## Rio de Janeiro — ISP-RJ

### Fontes identificadas

- **ISPDados** (portal oficial de dados abertos)
  <https://www.ispdados.rj.gov.br/>
  Bases de dados de Registros de Ocorrência (RO) + atividade policial.

- **ISP Conecta** — painéis interativos
  <https://www.ispconecta.rj.gov.br/>

- **Portal Estado RJ — dados abertos do ISP**
  <https://dadosabertos.rj.gov.br/organization/isp>

### Pré-conclusão

ISPDados é a fonte mais madura do Brasil para dados de segurança. Suporta download de bases consolidadas. A questão crítica é granularidade espacial (provavelmente AISP — área integrada — não bairro).

### Próximos passos

1. Baixar 1 base mensal recente em CSV
2. Verificar se há coluna de bairro ou apenas AISP/CISP
3. Avaliar se granularidade AISP é utilizável (cobre N bairros agregados)
4. Cobertura inclui região metropolitana ou só capital?

---

## Outros estados (referência)

- **São Paulo (SSP-SP)** — <https://www.ssp.sp.gov.br/estatistica/>
  Tem PDA (Plano de Dados Abertos) com CSV/XLSX. Granularidade município (não bairro).
- **Rio Grande do Sul (SSP-RS)** — <https://www.ssp.rs.gov.br/estatisticas>
- **Pernambuco** — fortemente coberto pelo Fogo Cruzado (priorizar API direta)
- **Federal — dados.gov.br** — <https://dados.gov.br/dados/conjuntos-dados/sistema-nacional-de-estatisticas-de-seguranca-publica>
  SINESP. Útil como baseline nacional.

---

## Hipótese inicial de cidade piloto

Antes da auditoria detalhada, ranking de candidatas:

| Cidade | Vantagem | Risco |
|---|---|---|
| **Rio de Janeiro** | ISPDados maduro + Fogo Cruzado | Concorrência mais cara, distância do autor |
| **Recife** | Fogo Cruzado nativo | SDS-PE com dados estruturados a confirmar |
| **Salvador** | Proximidade do autor, base de usuários | SSP-BA aparenta ser apenas painel/PDF |
| **São Paulo** | Maior mercado | Granularidade só municipal |

**Recomendação inicial:** focar a auditoria detalhada em Salvador (preferência operacional) e Recife (backup). Se Salvador falhar em granularidade, Recife com Fogo Cruzado vira o piloto.

---

## Sources iniciais

- [Transparência Bahia - Segurança Pública](https://www.transparencia.ba.gov.br/PainelEstatisticoSegurancaPublica)
- [SSP-BA Publicações](https://www.ba.gov.br/ssp/publicacoes/Estat%C3%ADstica)
- [ISPDados Abertos (RJ)](https://www.ispdados.rj.gov.br/)
- [ISP Conecta (RJ)](https://www.ispconecta.rj.gov.br/)
- [Portal Estado RJ - dados abertos ISP](https://dadosabertos.rj.gov.br/organization/isp)
- [SSP-SP estatística](https://www.ssp.sp.gov.br/estatistica/)
- [SINESP (federal)](https://dados.gov.br/dados/conjuntos-dados/sistema-nacional-de-estatisticas-de-seguranca-publica)

## Status

Pesquisa preliminar concluída. **Auditoria detalhada (download de amostras, verificação de granularidade) ainda TODO.**
