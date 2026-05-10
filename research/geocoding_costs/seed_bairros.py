"""
Popula bairros_salvador.json com bairros oficiais via Overpass API (OpenStreetMap).

Uso:
    python seed_bairros.py [cidade]

Default: Salvador. Para outra cidade, ajustar query Overpass.

Saída:
    bairros_<cidade>.json — dict {nome: {lat, lng, source}}
"""

import json
import sys
from pathlib import Path

import requests

DIR = Path(__file__).parent

OVERPASS_URL = "https://overpass-api.de/api/interpreter"

QUERY_SALVADOR = """
[out:json][timeout:60];
area["name"="Salvador"]["admin_level"="8"]->.cidade;
(
  relation(area.cidade)["place"="suburb"];
  relation(area.cidade)["place"="neighbourhood"];
  way(area.cidade)["place"="suburb"];
  way(area.cidade)["place"="neighbourhood"];
  node(area.cidade)["place"="suburb"];
  node(area.cidade)["place"="neighbourhood"];
);
out center tags;
"""


def fetch_bairros(query: str) -> dict:
    print(f"Consultando Overpass API…")
    headers = {"User-Agent": "projeto-seguranca-urbana-research/0.1"}
    r = requests.post(OVERPASS_URL, data={"data": query}, headers=headers, timeout=120)
    r.raise_for_status()
    data = r.json()
    bairros = {}
    for el in data.get("elements", []):
        name = el.get("tags", {}).get("name")
        if not name:
            continue
        if "center" in el:
            lat, lng = el["center"]["lat"], el["center"]["lon"]
        elif "lat" in el:
            lat, lng = el["lat"], el["lon"]
        else:
            continue
        bairros[name] = {"lat": lat, "lng": lng, "source": "OSM"}
    return bairros


def main() -> int:
    cidade = sys.argv[1] if len(sys.argv) > 1 else "salvador"
    if cidade.lower() != "salvador":
        sys.exit("apenas Salvador implementado por enquanto. Edite QUERY para outra cidade.")

    bairros = fetch_bairros(QUERY_SALVADOR)
    out = DIR / f"bairros_{cidade.lower()}.json"
    out.write_text(json.dumps(bairros, indent=2, ensure_ascii=False))
    print(f"\n{len(bairros)} bairros salvos em {out.name}")
    print("Top 10:")
    for name in list(bairros.keys())[:10]:
        print(f"  {name}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
