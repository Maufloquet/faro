"""
Popula dicionários de bairros para cidades da RMS (Região Metropolitana
de Salvador) via Overpass API.

Cidades:
- Camaçari
- Lauro de Freitas
- Simões Filho

Saída: bairros_<cidade>.json em cada destino.
"""

import json
import sys
from pathlib import Path

import requests

OVERPASS_URL = "https://overpass-api.de/api/interpreter"

CITIES = [
    ("camacari", "Camaçari"),
    ("lauro_de_freitas", "Lauro de Freitas"),
    ("simoes_filho", "Simões Filho"),
]


def query_for(city_name: str) -> str:
    return f"""
[out:json][timeout:60];
area["name"="{city_name}"]["admin_level"="8"]->.cidade;
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
    headers = {"User-Agent": "faro-rms-seed/0.1"}
    r = requests.post(
        OVERPASS_URL, data={"data": query}, headers=headers, timeout=120
    )
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


def main():
    base_app = Path(__file__).resolve().parents[2] / "app" / "assets"
    base_funcs = Path(__file__).resolve().parents[2] / "functions"
    base_app.mkdir(parents=True, exist_ok=True)

    for slug, name in CITIES:
        print(f"\nConsultando Overpass: {name}…")
        try:
            bairros = fetch_bairros(query_for(name))
        except Exception as e:
            print(f"  erro: {e}")
            continue

        # Salva nos dois locais (app + functions usam ambos)
        for dest in (base_app, base_funcs):
            out = dest / f"bairros_{slug}.json"
            out.write_text(json.dumps(bairros, indent=2, ensure_ascii=False))
            print(f"  {len(bairros):3d} bairros salvos em {out.relative_to(out.parents[2])}")


if __name__ == "__main__":
    main()
