#!/usr/bin/env node
/**
 * Recupera bairro de ocorrências em `city-centroid` varrendo o
 * `externalTitle` em busca de nomes de bairros do dicionário.
 *
 * Por que existir: quando o LLM extraiu um bairro mas ele não estava
 * no dicionário, o `resolveBairro` original caiu em `city-centroid` e
 * gravou `neighborhood = null` — perdendo a informação. Reprocessar
 * com `resolveBairro` puro não recupera porque o input já está vazio.
 *
 * Este script faz uma segunda passada heurística: lê o título da
 * matéria, procura por nomes de bairros (word boundary, case + acento
 * insensitive), e atualiza o doc se encontrar match único.
 *
 * Estratégia anti-falso-positivo:
 *  - Ordena bairros por tamanho decrescente — "Barra do Pojuca" tenta
 *    antes de "Barra", evitando match parcial
 *  - Match com word boundary (\b) — "Lapa" não bate dentro de "Lapinha"
 *  - Bairros muito curtos (< 5 chars) só fazem match se a cidade do
 *    doc bater com a cidade do bairro (reduz ambiguidade entre cidades)
 *  - Se múltiplos bairros baterem com tamanhos iguais → ambíguo, pula
 *
 * Uso:
 *   gcloud auth application-default login   # primeira vez
 *   node scripts/infer_neighborhood_from_title.js [opções]
 *
 * Opções:
 *   --dry-run        Mostra o que mudaria, NÃO grava.
 *   --limit N        Processa só N docs (default: todos em centroide).
 *   --days N         Janela em dias (default: 30).
 */

"use strict";

const admin = require("firebase-admin");
const path = require("path");
const fs = require("fs");
const ngeohash = require("ngeohash");

const { resolveCityKey } = require("../lib/cityCentroids");

function parseArgs(argv) {
  const out = { dryRun: false, limit: Infinity, days: 30 };
  for (let i = 2; i < argv.length; i++) {
    const a = argv[i];
    if (a === "--dry-run") out.dryRun = true;
    else if (a === "--limit") out.limit = parseInt(argv[++i], 10);
    else if (a === "--days") out.days = parseInt(argv[++i], 10);
    else {
      console.error(`Opção desconhecida: ${a}`);
      process.exit(2);
    }
  }
  return out;
}

function stripAccents(s) {
  return s.normalize("NFD").replace(/\p{Diacritic}/gu, "");
}

function escapeRegex(s) {
  return s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

// Carrega o dict como lista plana ordenada por tamanho do nome
// decrescente. Match mais longo vence — "Barra do Pojuca" antes de
// "Barra", "São Cristóvão" antes de "São", etc.
function loadAllBairros() {
  const cityFiles = {
    salvador: "bairros_salvador.json",
    camacari: "bairros_camacari.json",
    lauro_de_freitas: "bairros_lauro_de_freitas.json",
    simoes_filho: "bairros_simoes_filho.json",
  };
  const all = [];
  for (const [cityKey, filename] of Object.entries(cityFiles)) {
    const file = path.join(__dirname, "..", filename);
    if (!fs.existsSync(file)) continue;
    const data = JSON.parse(fs.readFileSync(file, "utf-8"));
    for (const [name, v] of Object.entries(data)) {
      all.push({
        name,
        nameNorm: stripAccents(name.toLowerCase()),
        lat: v.lat,
        lng: v.lng,
        cityKey,
      });
    }
  }
  // Ordena por tamanho do nameNorm decrescente
  all.sort((a, b) => b.nameNorm.length - a.nameNorm.length);
  return all;
}

const SHORT_NAME_MAX = 5; // <= 5 chars exige cidade casando

function findMatchesInTitle(title, allBairros, docCityKey) {
  if (!title) return [];
  const titleNorm = stripAccents(title.toLowerCase());
  const matches = [];
  for (const b of allBairros) {
    // Word boundary impede que "Lapa" bata dentro de "Lapinha"
    const re = new RegExp(`\\b${escapeRegex(b.nameNorm)}\\b`, "u");
    if (!re.test(titleNorm)) continue;

    // Nomes curtos só matam ambiguidade quando a cidade bate
    if (b.nameNorm.length <= SHORT_NAME_MAX) {
      if (!docCityKey || b.cityKey !== docCityKey) continue;
    }
    matches.push(b);
  }
  return matches;
}

async function main() {
  const opts = parseArgs(process.argv);
  if (!admin.apps.length) {
    admin.initializeApp({ projectId: "faro-f3472" });
  }
  const db = admin.firestore();

  const allBairros = loadAllBairros();
  console.log(`✓ ${allBairros.length} bairros carregados do dict`);

  const cutoff = new Date(Date.now() - opts.days * 24 * 60 * 60 * 1000);
  console.log(
    `→ buscando occurrences city-centroid · source=media · últimos ${opts.days}d` +
      (opts.dryRun ? " · DRY-RUN" : ""),
  );

  const snap = await db
    .collection("occurrences")
    .where("date", ">=", admin.firestore.Timestamp.fromDate(cutoff))
    .orderBy("date", "desc")
    .limit(5000)
    .get();
  const docs = snap.docs.filter((d) => {
    const data = d.data();
    return data.source === "media" && data.geocodeMethod === "city-centroid";
  });
  const work = Number.isFinite(opts.limit) ? docs.slice(0, opts.limit) : docs;
  console.log(`✓ ${work.length} docs city-centroid a inspecionar\n`);
  if (work.length === 0) return;

  const stats = {
    processed: 0,
    matched: 0,
    ambiguous: 0,
    no_title: 0,
    no_match: 0,
    updated: 0,
    errors: 0,
  };

  for (const doc of work) {
    stats.processed++;
    try {
      const data = doc.data();
      const title = data.externalTitle;
      if (!title) {
        stats.no_title++;
        continue;
      }
      const docCityKey = resolveCityKey(data.city);
      const matches = findMatchesInTitle(title, allBairros, docCityKey);

      if (matches.length === 0) {
        stats.no_match++;
        continue;
      }

      // Pega o(s) match(es) de tamanho máximo (mais específicos)
      const maxLen = matches[0].nameNorm.length;
      const top = matches.filter((m) => m.nameNorm.length === maxLen);

      if (top.length > 1) {
        // Empate de tamanho — ambíguo, não atualiza
        stats.ambiguous++;
        console.log(
          `  ? ambíguo: ${doc.id.slice(0, 18)}… (${top.map((t) => t.name).join(", ")}) "${title.slice(0, 60)}…"`,
        );
        continue;
      }

      const chosen = top[0];
      stats.matched++;
      console.log(
        `  + ${doc.id.slice(0, 18)}… [centroid→${chosen.name}|${chosen.cityKey}] "${title.slice(0, 60)}…"`,
      );

      if (!opts.dryRun) {
        await doc.ref.update({
          latitude: chosen.lat,
          longitude: chosen.lng,
          geohash: ngeohash.encode(chosen.lat, chosen.lng, 8),
          neighborhood: chosen.name,
          geocodeMethod: "title-inference",
          geocodeMatched: chosen.name,
          regeocodedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        stats.updated++;
      }
    } catch (e) {
      stats.errors++;
      console.error(`  ! erro em ${doc.id}: ${e.message}`);
    }
  }

  console.log("\nResultado:");
  console.log(`  processados:    ${stats.processed}`);
  console.log(`  matched único:  ${stats.matched} ✅`);
  console.log(`  ambíguos:       ${stats.ambiguous}`);
  console.log(`  sem título:     ${stats.no_title}`);
  console.log(`  sem match:      ${stats.no_match}`);
  console.log(`  gravados:       ${stats.updated}`);
  console.log(`  erros:          ${stats.errors}`);
  if (opts.dryRun) {
    console.log("\nDRY-RUN: nada foi gravado. Rode sem --dry-run pra aplicar.");
  }
}

main()
  .then(() => process.exit(0))
  .catch((e) => {
    console.error("FATAL:", e);
    process.exit(1);
  });
