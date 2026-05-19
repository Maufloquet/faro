#!/usr/bin/env node
/**
 * Reprocessa o campo `busLines` (e `transportContext`) das ocorrências
 * `source = "media"` dos últimos 30 dias, usando a versão atual do
 * classificador IA (groqClient.js) + sanitizer (newsIngest.js).
 *
 * Por que existir: o pipeline original aceitava só códigos numéricos
 * de linha — formato raríssimo em matérias de jornal. A versão nova
 * aceita também origem-destino ("Cajazeiras-Lapa"). Reprocessar pega
 * matérias antigas que ficaram com `busLines: []` mas tinham informação
 * de linha no título.
 *
 * Uso:
 *   gcloud auth application-default login   # primeira vez
 *   GROQ_API_KEY=xxx node scripts/reprocess_bus_lines.js [opções]
 *
 * Opções:
 *   --dry-run        Mostra o que mudaria, NÃO grava.
 *   --limit N        Processa só os N mais recentes (default: todos).
 *   --days N         Janela em dias (default: 30).
 *
 * Rate limit: dorme 250ms entre chamadas (≈ 4/s, bem abaixo dos
 * 30/min do Groq free tier). 500 docs → ~2min.
 */

"use strict";

const admin = require("firebase-admin");
const { classify } = require("../lib/groqClient");
const { _internal } = require("../lib/newsIngest");
const { sanitizeBusLines, sanitizeTransportContext } = _internal;

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

function sleep(ms) {
  return new Promise((r) => setTimeout(r, ms));
}

function arraysEqual(a, b) {
  if (!Array.isArray(a) || !Array.isArray(b)) return a === b;
  if (a.length !== b.length) return false;
  for (let i = 0; i < a.length; i++) if (a[i] !== b[i]) return false;
  return true;
}

async function main() {
  const opts = parseArgs(process.argv);
  if (!process.env.GROQ_API_KEY) {
    console.error("GROQ_API_KEY não setado.");
    process.exit(1);
  }
  if (!admin.apps.length) {
    admin.initializeApp({ projectId: "faro-f3472" });
  }
  const db = admin.firestore();

  const cutoff = new Date(Date.now() - opts.days * 24 * 60 * 60 * 1000);
  console.log(
    `→ buscando occurrences source=media · últimos ${opts.days}d` +
      (Number.isFinite(opts.limit) ? ` · limit ${opts.limit}` : "") +
      (opts.dryRun ? " · DRY-RUN" : ""),
  );

  let query = db
    .collection("occurrences")
    .where("source", "==", "media")
    .where("date", ">=", admin.firestore.Timestamp.fromDate(cutoff))
    .orderBy("date", "desc");
  if (Number.isFinite(opts.limit)) query = query.limit(opts.limit);
  const snap = await query.get();

  console.log(`✓ ${snap.size} documentos a reprocessar`);
  if (snap.empty) return;

  const stats = {
    processed: 0,
    changed: 0,
    skipped_no_title: 0,
    errors: 0,
    new_lines: 0,
  };

  for (const doc of snap.docs) {
    stats.processed++;
    const data = doc.data();
    const title = data.externalTitle;
    if (!title || typeof title !== "string") {
      stats.skipped_no_title++;
      continue;
    }

    try {
      // Re-classifica usando título (não temos descrição salva — best-effort)
      const classification = await classify(title, "");
      const newBusLines = sanitizeBusLines(classification.bus_lines);
      const newTransport = sanitizeTransportContext(
        classification.transport_context,
      );
      const oldBusLines = Array.isArray(data.busLines) ? data.busLines : [];
      const oldTransport = data.transportContext ?? null;

      const linesChanged = !arraysEqual(oldBusLines, newBusLines);
      const transportChanged = oldTransport !== newTransport;

      if (linesChanged || transportChanged) {
        stats.changed++;
        if (newBusLines.length > oldBusLines.length) {
          stats.new_lines += newBusLines.length - oldBusLines.length;
        }
        const fromTo = `[${oldBusLines.join(",")}] → [${newBusLines.join(",")}]`;
        console.log(
          `  ${doc.id.slice(0, 18)}… · "${title.slice(0, 60)}" · ${fromTo}`,
        );
        if (!opts.dryRun) {
          await doc.ref.update({
            busLines: newBusLines,
            transportContext: newTransport,
            reprocessedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (e) {
      stats.errors++;
      console.error(`  ! erro em ${doc.id}: ${e.message}`);
    }

    // Rate limit defensivo (30 req/min free tier → ~5/s seria limite;
    // 4/s deixa margem se outras funções rodarem em paralelo).
    await sleep(250);

    if (stats.processed % 50 === 0) {
      console.log(
        `  … ${stats.processed}/${snap.size} (mudou=${stats.changed}, +linhas=${stats.new_lines}, erros=${stats.errors})`,
      );
    }
  }

  console.log("");
  console.log("Resultado:");
  console.log(`  processados:           ${stats.processed}`);
  console.log(`  mudaram:               ${stats.changed}`);
  console.log(`  novas linhas extraídas: ${stats.new_lines}`);
  console.log(`  sem título (skip):     ${stats.skipped_no_title}`);
  console.log(`  erros:                 ${stats.errors}`);
  if (opts.dryRun) {
    console.log("");
    console.log("DRY-RUN: nada foi gravado. Rode sem --dry-run pra aplicar.");
  }
}

main()
  .then(() => process.exit(0))
  .catch((e) => {
    console.error("FATAL:", e);
    process.exit(1);
  });
