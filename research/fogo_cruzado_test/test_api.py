"""
Teste da API do Fogo Cruzado — cobertura por estado.

Pré-requisitos:
1. Cadastro em https://api.fogocruzado.org.br
2. cp .env.example .env e preencher FOGO_CRUZADO_EMAIL + FOGO_CRUZADO_PASSWORD
3. pip install -r requirements.txt
4. python test_api.py

Saída:
- samples/sample_<estado>.json — 100 ocorrências mais recentes de cada estado
- samples/coverage_full.json — sumário consolidado
- Print no terminal com conclusão sobre Salvador

Critério de aprovação:
- Login OK
- Pelo menos 1 estado com >= 100 ocorrências geocodificadas
- Idealmente Salvador (BA) com volume relevante
"""

from __future__ import annotations

import json
import os
import sys
import time
from collections import Counter
from pathlib import Path
from typing import Optional

import requests
from dotenv import load_dotenv

load_dotenv()

EMAIL = os.environ.get("FOGO_CRUZADO_EMAIL")
PASSWORD = os.environ.get("FOGO_CRUZADO_PASSWORD")

if not EMAIL or not PASSWORD:
    sys.exit("erro: FOGO_CRUZADO_EMAIL e FOGO_CRUZADO_PASSWORD devem estar no .env")

BASE_URL = "https://api-service.fogocruzado.org.br/api/v2"
SAMPLES_DIR = Path(__file__).parent / "samples"
SAMPLES_DIR.mkdir(exist_ok=True)


def get_token() -> str:
    print("autenticando…")
    t0 = time.time()
    r = requests.post(
        f"{BASE_URL}/auth/login",
        json={"email": EMAIL, "password": PASSWORD},
        timeout=15,
    )
    r.raise_for_status()
    print(f"  login ok em {(time.time() - t0) * 1000:.0f}ms")
    return r.json()["data"]["accessToken"]


def fetch_json(url: str, headers: dict, params: Optional[dict] = None) -> dict:
    t0 = time.time()
    r = requests.get(url, headers=headers, params=params, timeout=30)
    print(f"  GET {url.split('/api/v2')[-1]} {params or ''} → {r.status_code} em {(time.time() - t0) * 1000:.0f}ms")
    r.raise_for_status()
    return r.json()


def fetch_states(headers: dict) -> list[dict]:
    return fetch_json(f"{BASE_URL}/states", headers)["data"]


def fetch_occurrences_for_state(headers: dict, state_id: str, take: int = 100) -> list[dict]:
    payload = fetch_json(
        f"{BASE_URL}/occurrences",
        headers,
        params={"idState": state_id, "take": take, "order": "DESC", "page": 1},
    )
    return payload.get("data", [])


def field(o: dict, path: str, default=None):
    cur = o
    for k in path.split("."):
        if isinstance(cur, dict) and k in cur:
            cur = cur[k]
        else:
            return default
    return cur


def analyze(items: list[dict], state_name: str) -> dict:
    cities = Counter(field(o, "city.name") or "?" for o in items)
    neighs = Counter(field(o, "neighborhood.name") or "?" for o in items)
    with_geo = sum(1 for o in items if o.get("latitude") and o.get("longitude"))
    return {
        "state": state_name,
        "total": len(items),
        "with_geocoordinates": with_geo,
        "most_recent": items[0].get("date") if items else None,
        "oldest_in_sample": items[-1].get("date") if items else None,
        "cities_top10": dict(cities.most_common(10)),
        "neighborhoods_top15": dict(neighs.most_common(15)),
    }


def main() -> int:
    print("=== Teste API Fogo Cruzado ===\n")

    try:
        token = get_token()
    except requests.HTTPError as e:
        print(f"falha no login: {e.response.text[:300] if e.response else e}")
        return 1

    headers = {"Authorization": f"Bearer {token}"}

    print("\nbuscando estados disponíveis…")
    states = fetch_states(headers)
    print(f"  {len(states)} estados: {', '.join(s['name'] for s in states)}")

    print("\nbuscando 100 ocorrências mais recentes de cada estado…")
    summary = {}
    for state in states:
        try:
            items = fetch_occurrences_for_state(headers, state["id"])
            (SAMPLES_DIR / f"sample_{state['name'].lower().replace(' ', '_')}.json").write_text(
                json.dumps(items, indent=2, ensure_ascii=False)
            )
            summary[state["name"]] = analyze(items, state["name"])
        except requests.HTTPError as e:
            print(f"  erro em {state['name']}: {e.response.text[:200] if e.response else e}")
            summary[state["name"]] = {"error": str(e)}

    (SAMPLES_DIR / "coverage_full.json").write_text(
        json.dumps(summary, indent=2, ensure_ascii=False)
    )

    print("\n" + "=" * 60)
    print("RESULTADO POR ESTADO")
    print("=" * 60)
    for name, s in summary.items():
        if "error" in s:
            print(f"\n{name}: erro — {s['error']}")
            continue
        print(f"\n{name}")
        print(f"  Total na amostra: {s['total']}")
        print(f"  Com geocoordenadas: {s['with_geocoordinates']}/{s['total']}")
        print(f"  Mais recente: {s['most_recent']}")
        print(f"  Mais antigo na amostra: {s['oldest_in_sample']}")
        print(f"  Cidades top-5:")
        for city, n in list(s["cities_top10"].items())[:5]:
            print(f"    {city:30s} {n}")

    print("\n" + "=" * 60)
    print("CONCLUSÃO PARA PILOTO SALVADOR")
    print("=" * 60)
    bahia = summary.get("Bahia", {})
    if "error" in bahia:
        print("✗ Erro ao buscar Bahia. Validação não pôde ser concluída.")
        return 2

    salvador_count = sum(
        n for c, n in bahia.get("cities_top10", {}).items()
        if "salvador" in c.lower()
    )
    if salvador_count > 0:
        print(f"✓ Salvador aparece na top-10 da BA com {salvador_count} ocorrências na amostra de 100.")
    else:
        print(f"⚠ Salvador não está na top-10 da BA.")
        print(f"  Cidades top-10 da BA: {list(bahia.get('cities_top10', {}).keys())[:10]}")

    bahia_geo = bahia.get("with_geocoordinates", 0)
    if bahia_geo >= 80:
        print(f"✓ Bahia tem {bahia_geo}/100 com geocoordenadas — qualidade aceitável.")
    else:
        print(f"⚠ Bahia tem só {bahia_geo}/100 com geocoordenadas.")

    return 0


if __name__ == "__main__":
    sys.exit(main())
