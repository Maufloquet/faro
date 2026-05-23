#!/usr/bin/env node
/**
 * Limpa do Firestore as ocorrências geocodificadas erradamente antes
 * dos fixes de 2026-05-23 (`fix(geocoding): corta 4 vetores...`).
 *
 * Os bugs antigos faziam:
 *  - Notícia de cidade não-coberta (Itabuna, Feira, etc.) virar Salvador
 *    via fallback de centroide + `|| "Bahia"` no stateLabel.
 *  - Bairros com nome igual em 2+ cidades (Centro, Itinga, Santo Antônio,
 *    Novo Horizonte, Parque São Paulo) acabarem em Salvador por causa
 *    do match cego inter-cidades.
 *
 * Critérios de descarte (todos aplicam a `source = "media"` por padrão;
 * Fogo Cruzado/OSM não passa pelo pipeline com bug):
 *
 *   A) state NÃO é "Bahia" — vestígio de tempos pré-isolamento BA.
 *   B) city fora da whitelist (Salvador/Camaçari/Lauro/Simões Filho).
 *   C) [--aggressive] city = "Salvador" + externalTitle SEM Salvador,
 *      sem bairro real de Salvador e sem RMS no texto — provável
 *      alucinação ou colisão de bairro.
 *
 * Critérios (A) e (B) são determinísticos: ou bate, ou não. Sempre
 * seguros pra apagar. (C) é heurístico, exige --aggressive E é
 * conservador (só apaga se zero indícios no texto).
 *
 * Modo padrão: DRY-RUN. Mostra o que apagaria sem tocar. Pra apagar
 * de verdade, passe --apply.
 *
 * Uso:
 *   gcloud auth application-default login   # primeira vez
 *   node scripts/cleanupBadGeocoding.js                  # dry-run
 *   node scripts/cleanupBadGeocoding.js --apply          # apaga
 *   node scripts/cleanupBadGeocoding.js --aggressive     # inclui critério C (dry-run)
 *   node scripts/cleanupBadGeocoding.js --aggressive --apply
 *   node scripts/cleanupBadGeocoding.js --source all     # inclui não-media (cuidado)
 *   node scripts/cleanupBadGeocoding.js --sample 20      # amostra maior no log
 */

"use strict";

const admin = require("firebase-admin");
const fs = require("fs");
const path = require("path");

const COVERED_CITIES = new Set([
  "salvador",
  "camaçari",
  "camacari",
  "lauro de freitas",
  "simões filho",
  "simoes filho",
]);

function normalize(s) {
  if (!s) return "";
  return String(s)
    .toLowerCase()
    .normalize("NFD")
    .replace(/[̀-ͯ]/g, "")
    .replace(/\s+/g, " ")
    .trim();
}

function parseArgs(argv) {
  const out = {
    apply: false,
    aggressive: false,
    source: "media",
    sample: 10,
  };
  for (let i = 2; i < argv.length; i++) {
    const a = argv[i];
    if (a === "--apply") out.apply = true;
    else if (a === "--aggressive") out.aggressive = true;
    else if (a === "--source" && argv[i + 1]) {
      out.source = argv[++i];
    } else if (a === "--sample" && argv[i + 1]) {
      out.sample = parseInt(argv[++i], 10) || 10;
    } else if (a === "--help" || a === "-h") {
      console.log(
        "Uso: node scripts/cleanupBadGeocoding.js [--apply] [--aggressive] [--source media|all] [--sample N]",
      );
      process.exit(0);
    }
  }
  return out;
}

/**
 * Carrega bairros reais de Salvador a partir do JSON ao lado do
 * functions/. Usado pelo critério C pra distinguir título sem indícios
 * de Salvador.
 */
function loadSalvadorBairros() {
  const file = path.join(__dirname, "..", "bairros_salvador.json");
  if (!fs.existsSync(file)) return new Set();
  const data = JSON.parse(fs.readFileSync(file, "utf-8"));
  return new Set(Object.keys(data).map((k) => normalize(k)));
}

const RMS_HINTS = ["rms", "regiao metropolitana", "salvador", "camacari", "lauro", "simoes filho"];

function classify(doc, salvadorBairros, opts) {
  const data = doc.data();
  const cityNorm = normalize(data.city);
  const stateNorm = normalize(data.state);
  const title = normalize(data.externalTitle);

  // Critério A: state diferente de Bahia
  if (data.state && stateNorm !== "bahia") {
    return { keep: false, reason: `A: state="${data.state}"` };
  }

  // Critério B: city fora da whitelist
  if (data.city && !COVERED_CITIES.has(cityNorm)) {
    return { keep: false, reason: `B: city="${data.city}" fora da whitelist` };
  }

  // Critério C (só com --aggressive): city="Salvador" mas sem indícios
  // textuais de Salvador ou bairros conhecidos no externalTitle.
  if (opts.aggressive && cityNorm === "salvador" && data.externalTitle) {
    const hasHint = RMS_HINTS.some((h) => title.includes(h));
    if (hasHint) return { keep: true };
    const hasBairro = [...salvadorBairros].some((b) => b.length >= 4 && title.includes(b));
    if (!hasBairro) {
      return {
        keep: false,
        reason: `C: title="${data.externalTitle?.slice(0, 80)}" sem indício de Salvador`,
      };
    }
  }

  return { keep: true };
}

async function main() {
  const opts = parseArgs(process.argv);

  if (!admin.apps.length) {
    admin.initializeApp({ projectId: "faro-f3472" });
  }
  const db = admin.firestore();
  const salvadorBairros = loadSalvadorBairros();

  console.log("─".repeat(60));
  console.log(
    `Modo: ${opts.apply ? "APLICAR (vai apagar!)" : "DRY-RUN (não apaga)"}`,
  );
  console.log(`Source filter: ${opts.source}`);
  console.log(`Aggressive (critério C): ${opts.aggressive ? "ON" : "off"}`);
  console.log("─".repeat(60));

  let query = db.collection("occurrences");
  if (opts.source !== "all") {
    query = query.where("source", "==", opts.source);
  }
  const snap = await query.get();

  console.log(`Total varridos: ${snap.size}`);

  const toDelete = [];
  const reasonCounts = {};

  for (const doc of snap.docs) {
    const verdict = classify(doc, salvadorBairros, opts);
    if (!verdict.keep) {
      toDelete.push({ ref: doc.ref, id: doc.id, reason: verdict.reason, data: doc.data() });
      const prefix = verdict.reason.split(":")[0];
      reasonCounts[prefix] = (reasonCounts[prefix] || 0) + 1;
    }
  }

  console.log(`Candidatos a apagar: ${toDelete.length}`);
  for (const [k, v] of Object.entries(reasonCounts)) {
    console.log(`  Critério ${k}: ${v}`);
  }

  if (toDelete.length === 0) {
    console.log("Nada a fazer.");
    return;
  }

  console.log(`\nAmostra (${Math.min(opts.sample, toDelete.length)} primeiros):`);
  for (const item of toDelete.slice(0, opts.sample)) {
    const d = item.data;
    console.log(
      `  ${item.id} · city=${d.city || "(null)"} · state=${d.state || "(null)"} · source=${d.source}`,
    );
    console.log(`    → ${item.reason}`);
    if (d.externalTitle) {
      console.log(`    title: ${d.externalTitle.slice(0, 100)}`);
    }
  }

  if (!opts.apply) {
    console.log(
      `\nDry-run finalizado. Rode com --apply pra apagar ${toDelete.length} docs.`,
    );
    return;
  }

  console.log(`\nApagando ${toDelete.length} docs...`);
  const writer = db.bulkWriter();
  let failures = 0;
  writer.onWriteError((err) => {
    failures++;
    console.warn(`Falha em ${err.documentRef.path}: ${err.message}`);
    return false;
  });
  for (const item of toDelete) {
    writer.delete(item.ref);
  }
  await writer.close();
  console.log(`Apagados: ${toDelete.length - failures}, falhas: ${failures}`);
}

main()
  .then(() => process.exit(0))
  .catch((e) => {
    console.error(e);
    process.exit(1);
  });
