#!/usr/bin/env node
/**
 * Reclassifica o geocoding de ocorrências `source = "media"` recentes
 * LENDO O CORPO da matéria — pra corrigir relatos que caíram em bairro
 * errado (ou no centróide da cidade) porque o pipeline antigo só via
 * título + resumo do RSS.
 *
 * Diferença pro `reprocess_geocoding.js`: aquele só re-roda o `resolveBairro`
 * no `neighborhood` JÁ GRAVADO (útil quando o dicionário muda). Este busca
 * o artigo, reclassifica com o Groq usando o texto completo, e reposiciona
 * a ocorrência no bairro do fato. Custa chamadas Groq + fetch de rede.
 *
 * Só consegue melhorar relatos cuja `externalUrl` é fetchável — os 6
 * portais com RSS direto (G1 BA, Correio, A Tarde, iBahia, BNews, Bahia
 * no Ar). Itens do Google News (link redirecionador) são pulados.
 *
 * Conservador por princípio:
 *   - Promove centróide → bairro específico (ganho claro). Atualiza.
 *   - Troca bairro específico errado → outro bairro que aparece no corpo.
 *     Atualiza (é o caso que o usuário relatou).
 *   - Rebaixa específico → centróide SÓ quando o bairro antigo nem aparece
 *     no corpo (sinal forte de que estava errado). Senão, não mexe.
 *   - Nunca apaga. Nunca mexe em fogo_cruzado/osm.
 *
 * Uso:
 *   gcloud auth application-default login   # primeira vez
 *   export GROQ_API_KEY=...                 # mesma key do secret
 *   node scripts/reprocess_geocoding_from_article.js --dry-run
 *   node scripts/reprocess_geocoding_from_article.js --limit 50
 *
 * Opções:
 *   --dry-run     Mostra o que mudaria, NÃO grava.
 *   --limit N     Processa só os N mais recentes (default: 100).
 *   --days N      Janela em dias (default: 14).
 */

"use strict";

const admin = require("firebase-admin");
const ngeohash = require("ngeohash");

const { classify } = require("../lib/groqClient");
const { fetchArticleText } = require("../lib/articleFetch");
const { resolveBairro } = require("../lib/bairrosDict");
const { resolveCityKey, isCoveredCity } = require("../lib/cityCentroids");
const {
  normalizeForMatch,
  cityAppearsInText,
  neighborhoodAppearsInText,
} = require("../lib/newsIngest")._internal;

function parseArgs(argv) {
  const out = { dryRun: false, limit: 100, days: 14 };
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

/**
 * Decide se o novo geocoding substitui o antigo. Puro — recebe o estado
 * antigo do doc, o resultado novo do resolveBairro e o haystack normalizado
 * do corpo, devolve {update: bool, reason: string}.
 */
function decideUpdate(oldDoc, resolved, haystack) {
  const oldMethod = oldDoc.geocodeMethod;
  const oldNeighborhood = oldDoc.neighborhood || null;
  const newMethod = resolved.method;
  const newNeighborhood =
    newMethod === "city-centroid" ? null : resolved.matched;

  const oldIsCentroid = oldMethod === "city-centroid";
  const newIsCentroid = newMethod === "city-centroid";

  // Promove centróide → bairro: ganho claro.
  if (oldIsCentroid && !newIsCentroid) {
    return { update: true, reason: "promovido centroid→bairro" };
  }
  // Troca de bairro específico: corpo aponta outro bairro.
  if (!oldIsCentroid && !newIsCentroid && newNeighborhood !== oldNeighborhood) {
    return { update: true, reason: "bairro corrigido" };
  }
  // Rebaixa específico → centróide só se o bairro antigo nem aparece no corpo.
  if (!oldIsCentroid && newIsCentroid) {
    const oldStillThere =
      oldNeighborhood && neighborhoodAppearsInText(oldNeighborhood, haystack);
    if (!oldStillThere) {
      return { update: true, reason: "rebaixado (bairro antigo ausente do corpo)" };
    }
    return { update: false, reason: "mantido (bairro antigo confirmado no corpo)" };
  }
  return { update: false, reason: "sem mudança relevante" };
}

async function main() {
  const opts = parseArgs(process.argv);
  if (!process.env.GROQ_API_KEY) {
    console.error("GROQ_API_KEY ausente no ambiente. export GROQ_API_KEY=...");
    process.exit(2);
  }
  if (!admin.apps.length) {
    admin.initializeApp({ projectId: "faro-f3472" });
  }
  const db = admin.firestore();

  const cutoff = new Date(Date.now() - opts.days * 24 * 60 * 60 * 1000);
  console.log(
    `→ reclassificando via corpo · source=media · últimos ${opts.days}d · ` +
      `limite ${opts.limit}` + (opts.dryRun ? " · DRY-RUN" : ""),
  );

  const snap = await db
    .collection("occurrences")
    .where("date", ">=", admin.firestore.Timestamp.fromDate(cutoff))
    .orderBy("date", "desc")
    .limit(opts.limit * 3)
    .get();
  const work = snap.docs
    .filter((d) => d.data().source === "media" && d.data().externalUrl)
    .slice(0, opts.limit);
  console.log(`✓ ${work.length} docs media com URL a revisar\n`);
  if (work.length === 0) return;

  const stats = {
    processed: 0,
    bodyMissing: 0,
    notSecurity: 0,
    cityUncovered: 0,
    changed: 0,
    unchanged: 0,
    errors: 0,
  };

  for (const doc of work) {
    stats.processed++;
    const data = doc.data();
    try {
      const body = await fetchArticleText(data.externalUrl);
      if (!body) {
        stats.bodyMissing++;
        continue;
      }

      const c = await classify(data.externalTitle || "", "", body);
      if (!c.security_related || (c.confidence ?? 0) < 0.55) {
        stats.notSecurity++;
        continue;
      }
      const cityKey = resolveCityKey(c.city);
      if (!cityKey || !isCoveredCity(cityKey)) {
        stats.cityUncovered++;
        continue;
      }

      const haystack = normalizeForMatch(`${data.externalTitle || ""} ${body}`);
      if (!cityAppearsInText(c.city, haystack)) {
        stats.cityUncovered++;
        continue;
      }
      let safeNeighborhood = c.neighborhood;
      if (safeNeighborhood && !neighborhoodAppearsInText(safeNeighborhood, haystack)) {
        safeNeighborhood = null;
      }

      const resolved = resolveBairro(safeNeighborhood, c.city);
      if (!resolved) {
        stats.unchanged++;
        continue;
      }

      const decision = decideUpdate(data, resolved, haystack);
      if (!decision.update) {
        stats.unchanged++;
        continue;
      }

      stats.changed++;
      const title = (data.externalTitle || "").slice(0, 55);
      const newN = resolved.method === "city-centroid" ? "—" : resolved.matched;
      console.log(
        `  ${doc.id.slice(0, 18)}… [${data.neighborhood || "—"}→${newN}] ` +
          `${decision.reason} · "${title}…"`,
      );

      if (!opts.dryRun) {
        await doc.ref.update({
          latitude: resolved.lat,
          longitude: resolved.lng,
          geohash: ngeohash.encode(resolved.lat, resolved.lng, 8),
          neighborhood: resolved.method === "city-centroid" ? null : resolved.matched,
          geocodeMethod: resolved.method,
          geocodeMatched: resolved.matched,
          reclassifiedFromArticleAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      stats.errors++;
      console.error(`  ! erro em ${doc.id}: ${e.message}`);
    }
  }

  console.log("\nResultado:");
  console.log(`  processados:          ${stats.processed}`);
  console.log(`  corpo indisponível:   ${stats.bodyMissing} (Google News / fetch falhou)`);
  console.log(`  não-segurança:        ${stats.notSecurity}`);
  console.log(`  cidade fora cobertura:${stats.cityUncovered}`);
  console.log(`  corrigidos:           ${stats.changed} ✅`);
  console.log(`  sem mudança:          ${stats.unchanged}`);
  console.log(`  erros:                ${stats.errors}`);
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
