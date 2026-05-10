"""Descobre endpoints de metadata (estados, cidades) da API."""
import json
import os

import requests
from dotenv import load_dotenv

load_dotenv()

r = requests.post(
    "https://api-service.fogocruzado.org.br/api/v2/auth/login",
    json={
        "email": os.environ["FOGO_CRUZADO_EMAIL"],
        "password": os.environ["FOGO_CRUZADO_PASSWORD"],
    },
    timeout=15,
)
r.raise_for_status()
token = r.json()["data"]["accessToken"]
h = {"Authorization": f"Bearer {token}"}
BASE = "https://api-service.fogocruzado.org.br/api/v2"

for path in ["/states", "/cities", "/states/cities", "/regions"]:
    r = requests.get(f"{BASE}{path}", headers=h, timeout=15)
    print(f"GET {path} → {r.status_code}")
    if r.status_code == 200:
        data = r.json()
        print(json.dumps(data, indent=2, ensure_ascii=False)[:1500])
        print("---")
