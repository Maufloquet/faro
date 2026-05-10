# Teste de API do Fogo Cruzado

## Objetivo

Confirmar que a API pública do Fogo Cruzado é acessível, retorna dados geocodificados e tem cobertura útil para o produto.

## Por que importa

Fogo Cruzado é a única fonte brasileira de dados de tiroteios em tempo real com coordenadas. No relatório v3 (§6), ela tem peso 0.7 — mais alto que SSP histórica e que UGC inicial. Se a API não responder, mudar de assunto.

Limitação conhecida: cobertura inicial é Rio de Janeiro e Recife. Salvador (provável piloto do usuário) não está oficialmente coberto. Validar.

## Critério de aprovação

API responde com pelo menos 100 ocorrências reais nas últimas 30 dias, com:
- Latitude e longitude válidas (não placeholders)
- Timestamp ISO 8601
- Tipo de ocorrência categorizado
- Cobertura inclui Salvador OU outra cidade viável como piloto

## Plano de teste

### 1. Cadastro e API key

- Acessar <https://api.fogocruzado.org.br/>
- Solicitar API key (processo de cadastro com motivação de uso)
- Anotar limites de rate e cota

### 2. Exploração da API

Endpoints prováveis (confirmar na doc):
- `/occurrences` — lista de tiroteios com filtros geográficos e temporais
- `/cities` — lista de municípios cobertos

### 3. Teste mínimo

Script Python (a criar em `test_api.py`):

```python
import requests, os, json

API_KEY = os.environ["FOGO_CRUZADO_KEY"]
headers = {"Authorization": f"Bearer {API_KEY}"}

# 100 ocorrências mais recentes
r = requests.get(
    "https://api.fogocruzado.org.br/api/v2/occurrences",
    headers=headers,
    params={"take": 100}
)
data = r.json()

# Salvar amostra
with open("samples/sample_100.json", "w") as f:
    json.dump(data, f, indent=2, ensure_ascii=False)

# Validações
print(f"Status: {r.status_code}")
print(f"Total recebido: {len(data.get('data', []))}")
print(f"Cidades cobertas: {set(o.get('cityName') for o in data['data'])}")
print(f"Com lat/lng: {sum(1 for o in data['data'] if o.get('latitude'))}")
```

### 4. Resultado em `findings.md` (deste diretório)

Documentar:
- API respondeu? Latência média?
- Quantas ocorrências retornadas com geocoordenadas válidas?
- Lista de cidades cobertas
- Salvador está coberta?
- Se não, qual cidade viável (com Fogo Cruzado + SSP utilizável) é candidata a piloto?

## Tempo estimado

1 dia (4-6 horas).

## Status

TODO — depende de cadastro com API key.
