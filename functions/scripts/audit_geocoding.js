#!/usr/bin/env node
/**
 * Auditoria de geocoding das ocorrências em /occurrences no Firestore.
 *
 * Pergunta principal: quantas matérias estão sendo mapeadas pro
 * centroide da cidade (geolocalização genérica) vs nome de bairro real?
 * Se 60%+ está em city-centroid, o pipeline está falhando muito e os
 * pins do app representam pouco da realidade.
 *
 * Saída: estatísticas no stdout + amostra de matérias suspeitas.
 *
 * Uso:
 *   gcloud auth application-default login   # primeira vez
 *   node scripts/audit_geocoding.js [opções]
 *
 * Opções:
 *   --days N           Janela em dias (default: 30).
 *   --source X         Filtra source (default: 'media').
 *   --sample N         Mostra N amostras de matérias problemáticas
 *                      (default: 10).
 */

"use strict";

const admin = require("firebase-admin");

function parseArgs(argv) {
  const out = { days: 30, source: "media", sample: 10 };
  for (let i = 2; i < argv.length; i++) {
    const a = argv[i];
    if (a === "--days") out.days = parseInt(argv[++i], 10);
    else if (a === "--source") out.source = argv[++i];
    else if (a === "--sample") out.sample = parseInt(argv[++i], 10);
    else {
      console.error(`Opção desconhecida: ${a}`);
      process.exit(2);
    }
  }
  return out;
}

async function main() {
  const opts = parseArgs(process.argv);
  if (!admin.apps.length) {
    admin.initializeApp({ projectId: "faro-f3472" });
  }
  const db = admin.firestore();

  const cutoff = new Date(Date.now() - opts.days * 24 * 60 * 60 * 1000);
  console.log(
    `→ auditando occurrences source=${opts.source} últimos ${opts.days}d`,
  );

  // Filtra por date no servidor; source no cliente (evita exigir índice
  // composto novo só pra auditoria one-shot).
  const snap = await db
    .collection("occurrences")
    .where("date", ">=", admin.firestore.Timestamp.fromDate(cutoff))
    .orderBy("date", "desc")
    .get();
  const docs = snap.docs.filter((d) => d.data().source === opts.source);
  console.log(`✓ ${docs.length} docs ${opts.source} no período\n`);

  if (docs.length === 0) return;

  // Distribuição por geocodeMethod
  const byMethod = {};
  const byCity = {};
  const byNeighborhood = {};
  const cityCentroidDocs = [];
  const fuzzyDocs = [];
  const substringDocs = [];
  let noLocation = 0;

  for (const d of docs) {
    const data = d.data();
    const method = data.geocodeMethod || "(none)";
    byMethod[method] = (byMethod[method] || 0) + 1;

    const city = data.city || "(sem cidade)";
    byCity[city] = (byCity[city] || 0) + 1;

    const n = data.neighborhood || "(sem bairro)";
    byNeighborhood[n] = (byNeighborhood[n] || 0) + 1;

    if (data.latitude == null || data.longitude == null) noLocation++;

    if (method === "city-centroid") cityCentroidDocs.push(d);
    if (method === "fuzzy") fuzzyDocs.push(d);
    if (method === "substring") substringDocs.push(d);
  }

  console.log("─ Distribuição por geocodeMethod ─");
  const sortedMethods = Object.entries(byMethod).sort((a, b) => b[1] - a[1]);
  for (const [k, v] of sortedMethods) {
    const pct = ((v / docs.length) * 100).toFixed(1);
    const flag = k === "city-centroid" && v / docs.length > 0.5 ? " ⚠️" : "";
    console.log(`  ${k.padEnd(20)} ${String(v).padStart(5)}  (${pct}%)${flag}`);
  }

  console.log("\n─ Top 10 cidades ─");
  const sortedCities = Object.entries(byCity)
    .sort((a, b) => b[1] - a[1])
    .slice(0, 10);
  for (const [k, v] of sortedCities) {
    const pct = ((v / docs.length) * 100).toFixed(1);
    console.log(`  ${k.padEnd(30)} ${String(v).padStart(5)}  (${pct}%)`);
  }

  console.log("\n─ Top 15 bairros ─");
  const sortedNeigh = Object.entries(byNeighborhood)
    .sort((a, b) => b[1] - a[1])
    .slice(0, 15);
  for (const [k, v] of sortedNeigh) {
    const pct = ((v / docs.length) * 100).toFixed(1);
    console.log(`  ${k.padEnd(35)} ${String(v).padStart(5)}  (${pct}%)`);
  }

  if (substringDocs.length > 0 || fuzzyDocs.length > 0) {
    console.log("\n─ Amostra de matérias resolvidas por substring/fuzzy ─");
    console.log("  (revisar pra detectar falsos positivos)\n");
    const sus = [...substringDocs.slice(0, opts.sample / 2), ...fuzzyDocs.slice(0, opts.sample / 2)];
    for (const d of sus) {
      const data = d.data();
      const title = (data.externalTitle || "").slice(0, 80);
      console.log(
        `  · ${data.geocodeMethod.padEnd(10)} ${data.neighborhood} (${data.city}) — "${title}..."`,
      );
    }
  }

  if (cityCentroidDocs.length > 0) {
    const pct = ((cityCentroidDocs.length / docs.length) * 100).toFixed(0);
    console.log(`\n─ city-centroid (${pct}%) ─`);
    if (cityCentroidDocs.length / docs.length > 0.5) {
      console.log(
        "  ⚠️ Mais da metade das ocorrências caem no centroide da cidade.",
      );
      console.log(
        "  Pode ser sinal de: LLM não extrai bairro consistentemente,",
      );
      console.log(
        "  ou dicionário não cobre bairros mencionados nas matérias.\n",
      );
    }
    console.log("  Amostra de matérias caindo no centroide:");
    for (const d of cityCentroidDocs.slice(0, opts.sample)) {
      const data = d.data();
      const title = (data.externalTitle || "").slice(0, 90);
      console.log(`  · ${data.city} — "${title}..."`);
    }
  }

  if (noLocation > 0) {
    console.log(`\n⚠️ ${noLocation} docs sem lat/lng (deveria ser zero).`);
  }

  console.log("\n");
}

main()
  .then(() => process.exit(0))
  .catch((e) => {
    console.error("FATAL:", e);
    process.exit(1);
  });
