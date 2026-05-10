"""
Teste mínimo da API do Fogo Cruzado.

Pré-requisitos:
1. Cadastro em https://api.fogocruzado.org.br
2. Copiar .env.example para .env e preencher FOGO_CRUZADO_KEY
3. pip install -r requirements.txt
4. python test_api.py

Saída:
- samples/sample_100.json — 100 ocorrências mais recentes
- samples/coverage.json — cidades cobertas e contagem
- Print resumo no terminal

Critério de aprovação:
- API responde 2xx
- >= 100 ocorrências com latitude/longitude válidas
- Cobertura inclui cidade piloto (Salvador) ou alternativa viável
"""

import json
import os
import sys
import time
from collections import Counter
from pathlib import Path

import requests
from dotenv import load_dotenv

load_dotenv()

API_KEY = os.environ.get("FOGO_CRUZADO_KEY")
if not API_KEY:
    sys.exit("erro: FOGO_CRUZADO_KEY ausente no .env")

BASE_URL = "https://api.fogocruzado.org.br/api/v2"
SAMPLES_DIR = Path(__file__).parent / "samples"
SAMPLES_DIR.mkdir(exist_ok=True)


def get_token() -> str:
    """A API mais recente usa OAuth2 client_credentials. Ajustar conforme doc."""
    r = requests.post(
        f"{BASE_URL}/auth/login",
        json={"email": os.environ["FOGO_CRUZADO_EMAIL"], "password": os.environ["FOGO_CRUZADO_PASSWORD"]},
        timeout=10,
    )
    r.raise_for_status()
    return r.json()["data"]["accessToken"]


def fetch_occurrences(token: str, take: int = 100) -> dict:
    headers = {"Authorization": f"Bearer {token}"}
    t0 = time.time()
    r = requests.get(
        f"{BASE_URL}/occurrences",
        headers=headers,
        params={"take": take, "order": "DESC", "orderBy": "date"},
        timeout=15,
    )
    latency_ms = (time.time() - t0) * 1000
    print(f"GET /occurrences → {r.status_code} em {latency_ms:.0f}ms")
    r.raise_for_status()
    return r.json()


def analyze(payload: dict) -> dict:
    items = payload.get("data", [])
    cities = Counter(o.get("cityName") or o.get("city", {}).get("name", "?") for o in items)
    states = Counter(o.get("stateName") or o.get("state", {}).get("name", "?") for o in items)
    with_geo = sum(1 for o in items if o.get("latitude") and o.get("longitude"))
    return {
        "total": len(items),
        "with_geocoordinates": with_geo,
        "cities_covered": dict(cities.most_common()),
        "states_covered": dict(states.most_common()),
    }


def main() -> int:
    print("=== Teste API Fogo Cruzado ===")
    try:
        token = get_token() if os.environ.get("FOGO_CRUZADO_EMAIL") else API_KEY
    except Exception as e:
        print(f"falha no auth: {e}")
        print("se a API mudou para token estático, ajuste get_token() conforme doc atual")
        return 1

    payload = fetch_occurrences(token)
    coverage = analyze(payload)

    (SAMPLES_DIR / "sample_100.json").write_text(
        json.dumps(payload, indent=2, ensure_ascii=False)
    )
    (SAMPLES_DIR / "coverage.json").write_text(
        json.dumps(coverage, indent=2, ensure_ascii=False)
    )

    print(f"\nTotal recebido: {coverage['total']}")
    print(f"Com geocoordenadas: {coverage['with_geocoordinates']}")
    print(f"\nEstados cobertos:")
    for state, n in coverage["states_covered"].items():
        print(f"  {state:30s} {n}")
    print(f"\nCidades top-15:")
    for city, n in list(coverage["cities_covered"].items())[:15]:
        print(f"  {city:30s} {n}")

    salvador_count = sum(
        n for c, n in coverage["cities_covered"].items() if "salvador" in c.lower()
    )
    if salvador_count > 0:
        print(f"\n✓ Salvador coberto: {salvador_count} ocorrências na amostra")
    else:
        print(f"\n✗ Salvador NÃO está coberto na amostra. Considerar piloto em RJ ou Recife.")

    return 0


if __name__ == "__main__":
    sys.exit(main())
