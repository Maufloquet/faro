"""
Teste de custo de Geocoding em volume — comparativo de cenários.

Cenário A: 100% Google Geocoding API (baseline)
Cenário B: dicionário local de bairros + fuzzy match + Google como fallback

Pré-requisitos:
1. cp .env.example .env e preencher GOOGLE_GEOCODING_KEY
2. pip install -r requirements.txt
3. Popular sample_texts.txt com 500 textos reais de notícias com menções a localizações
4. Popular bairros_salvador.json (use seed_bairros.py para gerar via Overpass/IBGE)
5. python test_volume.py

Saída:
- results_cenario_a.json — resultado bruto Google
- results_cenario_b.json — resultado dicionário+fallback
- comparativo.md — tabela comparativa pronta para colar em findings.md

Critério de aprovação:
- Cenário B custo escalado mensal <= R$ 800
- Precisão Cenário B >= 85%
"""

import json
import os
import re
import sys
import time
from pathlib import Path

import requests
from dotenv import load_dotenv
from thefuzz import process

load_dotenv()

GOOGLE_KEY = os.environ.get("GOOGLE_GEOCODING_KEY")
if not GOOGLE_KEY:
    sys.exit("erro: GOOGLE_GEOCODING_KEY ausente no .env")

# Custo aproximado por chamada Google Geocoding (USD)
GOOGLE_COST_PER_CALL_USD = 0.005  # primeiras 100k/mês após cota grátis
USD_TO_BRL = 5.40

DIR = Path(__file__).parent
TEXTS_FILE = DIR / "sample_texts.txt"
BAIRROS_FILE = DIR / "bairros_salvador.json"


def google_geocode(query: str) -> dict | None:
    r = requests.get(
        "https://maps.googleapis.com/maps/api/geocode/json",
        params={"address": query, "key": GOOGLE_KEY, "region": "br"},
        timeout=10,
    )
    if r.status_code != 200:
        return None
    data = r.json()
    if data.get("status") != "OK" or not data.get("results"):
        return None
    loc = data["results"][0]["geometry"]["location"]
    return {"lat": loc["lat"], "lng": loc["lng"], "raw": data["results"][0]}


def cenario_a(texts: list[str]) -> dict:
    """Baseline: 100% Google."""
    print(f"\n=== Cenário A — Google direto ({len(texts)} textos) ===")
    results = []
    t0 = time.time()
    for i, text in enumerate(texts, 1):
        r = google_geocode(text)
        results.append({"text": text, "result": r})
        if i % 50 == 0:
            print(f"  {i}/{len(texts)} processados…")
    elapsed = time.time() - t0
    sucesso = sum(1 for r in results if r["result"])
    return {
        "calls_made": len(texts),
        "calls_paid": len(texts),
        "successes": sucesso,
        "elapsed_s": elapsed,
        "results": results,
    }


def cenario_b(texts: list[str], bairros: dict) -> dict:
    """Dicionário local + fuzzy + Google como fallback."""
    print(f"\n=== Cenário B — dicionário + fallback Google ({len(texts)} textos) ===")
    bairro_names = list(bairros.keys())
    results = []
    paid_calls = 0
    t0 = time.time()
    for i, text in enumerate(texts, 1):
        local = match_local(text, bairro_names, bairros)
        if local:
            results.append({"text": text, "result": local, "source": "local"})
        else:
            r = google_geocode(text)
            paid_calls += 1
            results.append({"text": text, "result": r, "source": "google"})
        if i % 50 == 0:
            print(f"  {i}/{len(texts)} processados…")
    elapsed = time.time() - t0
    sucesso = sum(1 for r in results if r["result"])
    return {
        "calls_made": len(texts),
        "calls_paid": paid_calls,
        "successes": sucesso,
        "local_resolved": len(texts) - paid_calls,
        "elapsed_s": elapsed,
        "results": results,
    }


def match_local(text: str, bairro_names: list[str], bairros: dict) -> dict | None:
    """Tenta achar bairro no texto: match exato → fuzzy."""
    text_lower = text.lower()
    for name in bairro_names:
        if re.search(rf"\b{re.escape(name.lower())}\b", text_lower):
            b = bairros[name]
            return {"lat": b["lat"], "lng": b["lng"], "matched": name, "method": "exact"}

    candidates = re.findall(r"\b[A-ZÁÉÍÓÚÂÊÔÃÕÇ][a-záéíóúâêôãõç]{3,}\b", text)
    for cand in candidates:
        match, score = process.extractOne(cand, bairro_names) or (None, 0)
        if score >= 88:
            b = bairros[match]
            return {
                "lat": b["lat"],
                "lng": b["lng"],
                "matched": match,
                "candidate": cand,
                "score": score,
                "method": "fuzzy",
            }
    return None


def cost_brl(calls: int, monthly_volume: int = 200_000) -> dict:
    """Estima custo escalado para volume mensal projetado do MVP."""
    sampled_paid_ratio = calls / max(1, monthly_volume / (200_000 / 500))
    monthly_paid = int((calls / 500) * monthly_volume)
    free_tier = 10_000
    paid_after_free = max(0, monthly_paid - free_tier)
    cost_usd = paid_after_free * GOOGLE_COST_PER_CALL_USD
    cost_brl = cost_usd * USD_TO_BRL
    return {
        "monthly_paid_calls_projected": monthly_paid,
        "after_free_tier": paid_after_free,
        "cost_brl_per_month": round(cost_brl, 2),
    }


def main() -> int:
    if not TEXTS_FILE.exists():
        sys.exit(f"erro: {TEXTS_FILE} não existe. Crie com 500 textos reais (1 por linha).")
    if not BAIRROS_FILE.exists():
        sys.exit(f"erro: {BAIRROS_FILE} não existe. Rode seed_bairros.py primeiro.")

    texts = [line.strip() for line in TEXTS_FILE.read_text(encoding="utf-8").splitlines() if line.strip()]
    bairros = json.loads(BAIRROS_FILE.read_text(encoding="utf-8"))

    print(f"Textos carregados: {len(texts)}")
    print(f"Bairros no dicionário: {len(bairros)}")

    a = cenario_a(texts[:500])
    b = cenario_b(texts[:500], bairros)

    cost_a = cost_brl(a["calls_paid"])
    cost_b = cost_brl(b["calls_paid"])

    (DIR / "results_cenario_a.json").write_text(json.dumps(a, indent=2, ensure_ascii=False))
    (DIR / "results_cenario_b.json").write_text(json.dumps(b, indent=2, ensure_ascii=False))

    md = f"""# Comparativo de Cenários — Geocoding

| Métrica | Cenário A (baseline) | Cenário B (dicionário + fallback) |
|---|---|---|
| Chamadas pagas | {a['calls_paid']} | {b['calls_paid']} |
| Resolvidas localmente | 0 | {b['local_resolved']} |
| Sucessos | {a['successes']} | {b['successes']} |
| Precisão | {a['successes'] / max(1, len(texts[:500])) * 100:.1f}% | {b['successes'] / max(1, len(texts[:500])) * 100:.1f}% |
| Latência total (s) | {a['elapsed_s']:.1f} | {b['elapsed_s']:.1f} |
| Custo escalado /mês (R$) | {cost_a['cost_brl_per_month']} | {cost_b['cost_brl_per_month']} |

## Decisão

Cenário B aprovado se:
- Custo /mês <= R$ 800: {'✓' if cost_b['cost_brl_per_month'] <= 800 else '✗'}
- Precisão >= 85%: {'✓' if b['successes'] / max(1, len(texts[:500])) >= 0.85 else '✗'}
"""
    (DIR / "comparativo.md").write_text(md)

    print("\n" + md)
    return 0


if __name__ == "__main__":
    sys.exit(main())
