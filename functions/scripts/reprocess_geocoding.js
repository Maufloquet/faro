#!/usr/bin/env node
/**
 * Reprocessa o geocoding das ocorrências `source = "media"` dos últimos
 * N dias, usando a versão atual do `resolveBairro` (lib/bairrosDict.js).
 *
 * Por que existir: as correções de geocoding (bloquear substring de
 * nomes curtos, exactOnly no fallback inter-cidades) + bairros novos
 * adicionados ao dicionário não afetam ocorrências já gravadas. Esse
 * script revisita cada doc, roda o `resolveBairro` no `neighborhood +
 * city` originais, e atualiza apenas se o resultado divergir.
 *
 * Não chama LLM. Não custa nada além de Firestore reads/writes.
 *
 * Uso:
 *   gcloud auth application-default login   # primeira vez
 *   node scripts/reprocess_geocoding.js [opções]
 *
 * Opções:
 *   --dry-run        Mostra o que mudaria, NÃO grava.
 *   --limit N        Processa só os N mais recentes (default: todos).
 *   --days N         Janela em dias (default: 30).
 */

"use strict";

const admin = require("firebase-admin");
const ngeohash = require("ngeohash");
const { resolveBairro } = require("../lib/bairrosDict");

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

async function main() {
  const opts = parseArgs(process.argv);
  if (!admin.apps.length) {
    admin.initializeApp({ projectId: "faro-f3472" });
  }
  const db = admin.firestore();

  const cutoff = new Date(Date.now() - opts.days * 24 * 60 * 60 * 1000);
  console.log(
    `→ reprocessando geocoding · source=media · últimos ${opts.days}d` +
      (opts.dryRun ? " · DRY-RUN" : ""),
  );

  // Filtra source no client pra evitar exigir índice composto.
  // Pega bastante folga (3x) já que 12% do snap costuma ser fogo_cruzado.
  const limitWithBuffer = Number.isFinite(opts.limit) ? opts.limit * 3 : 5000;
  const snap = await db
    .collection("occurrences")
    .where("date", ">=", admin.firestore.Timestamp.fromDate(cutoff))
    .orderBy("date", "desc")
    .limit(limitWithBuffer)
    .get();
  const mediaDocs = snap.docs.filter((d) => d.data().source === "media");
  const work = Number.isFinite(opts.limit)
    ? mediaDocs.slice(0, opts.limit)
    : mediaDocs;
  console.log(`✓ ${work.length} docs media a reprocessar\n`);
  if (work.length === 0) return;

  const stats = {
    processed: 0,
    changed: 0,
    method_changed: 0,
    promoted_from_centroid: 0,
    demoted_to_centroid: 0,
    relocated: 0,
    skipped_no_input: 0,
    errors: 0,
  };

  for (const doc of work) {
    stats.processed++;
    const data = doc.data();

    // Inputs originais que o LLM extraiu — guardados ou inferidos.
    // Se não temos o neighborhood/city original explícitos no doc, não
    // dá pra reprocessar com fidelidade — pulamos.
    const origNeighborhood = data.neighborhood;
    const origCity = data.city;

    // OK reprocessar mesmo com neighborhood vazio (city-centroid path).
    if (!origCity && !origNeighborhood) {
      stats.skipped_no_input++;
      continue;
    }

    try {
      const resolved = resolveBairro(origNeighborhood, origCity);
      if (!resolved) {
        // Antes resolvia em algo, agora não? Raro. Mantemos como está.
        continue;
      }

      const oldLat = data.latitude;
      const oldLng = data.longitude;
      const oldMethod = data.geocodeMethod;
      const newLat = resolved.lat;
      const newLng = resolved.lng;
      const newMethod = resolved.method;

      const moved =
        Math.abs(oldLat - newLat) > 0.0005 ||
        Math.abs(oldLng - newLng) > 0.0005;
      const methodChanged = oldMethod !== newMethod;

      if (!moved && !methodChanged) continue;

      stats.changed++;
      if (methodChanged) stats.method_changed++;
      if (oldMethod === "city-centroid" && newMethod !== "city-centroid") {
        stats.promoted_from_centroid++;
      }
      if (oldMethod !== "city-centroid" && newMethod === "city-centroid") {
        stats.demoted_to_centroid++;
      }
      if (moved && !methodChanged) stats.relocated++;

      const title = (data.externalTitle || "").slice(0, 60);
      console.log(
        `  ${doc.id.slice(0, 18)}… ${oldMethod}→${newMethod} ` +
          `[${origNeighborhood || "—"}|${origCity || "—"}] "${title}…"`,
      );

      if (!opts.dryRun) {
        await doc.ref.update({
          latitude: newLat,
          longitude: newLng,
          geohash: ngeohash.encode(newLat, newLng, 8),
          geocodeMethod: newMethod,
          // matched: nome canônico do bairro encontrado, registra ao lado
          // do neighborhood original pra rastreabilidade
          geocodeMatched: resolved.matched,
          regeocodedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      stats.errors++;
      console.error(`  ! erro em ${doc.id}: ${e.message}`);
    }
  }

  console.log("\nResultado:");
  console.log(`  processados:               ${stats.processed}`);
  console.log(`  mudaram:                   ${stats.changed}`);
  console.log(`  promovidos centroid→bairro: ${stats.promoted_from_centroid} ✅`);
  console.log(`  rebaixados bairro→centroid: ${stats.demoted_to_centroid}`);
  console.log(`  realocados (mesmo método):  ${stats.relocated}`);
  console.log(`  sem input (skip):           ${stats.skipped_no_input}`);
  console.log(`  erros:                      ${stats.errors}`);
  if (opts.dryRun) {
    console.log("\nDRY-RUN: nada foi gravado. Rode sem --dry-run pra aplicar.");
  } else if (stats.changed > 0) {
    console.log(
      "\nGravado. Rode `node scripts/audit_geocoding.js` pra ver o impacto.",
    );
  }
}

main()
  .then(() => process.exit(0))
  .catch((e) => {
    console.error("FATAL:", e);
    process.exit(1);
  });
