"use strict";

/**
 * Scheduler que ingere notícias de portais e Google News, classifica via
 * Groq e grava ocorrências no Firestore com source='media'.
 *
 * Frequência: a cada 30 min (alinhado ao Fogo Cruzado sync).
 * Estado piloto: Bahia (SOURCES configuradas em newsSources.js).
 *
 * Pipeline por item:
 *   1. Fetch RSS de cada source habilitado
 *   2. Dedup global por hash da URL (item.link)
 *   3. Classifica título+descrição via Groq (Llama 3 70B)
 *   4. Se security_related + bairro identificado:
 *      - Geocoda via dicionário local (sem custo)
 *      - Grava em occurrences com source='media', weight da fonte
 *   5. Salva o hash em news_seen pra dedup futura
 *
 * Custo estimado:
 *   - ~5 sources × ~10 items/run × 48 runs/dia = 2.4k LLM calls/dia
 *   - Groq free tier: 14.4k calls/dia → sobra
 *   - Firestore: 1-2 writes/item × 100 items/dia = ~200 writes/dia
 */

const crypto = require("crypto");

const admin = require("firebase-admin");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { logger } = require("firebase-functions/v2");
const ngeohash = require("ngeohash");
const Parser = require("rss-parser");

const { enabledSources } = require("./newsSources");
const { classify } = require("./groqClient");
const { resolveBairro } = require("./bairrosDict");

const SOURCE = "media";
const PARSE_TIMEOUT_MS = 15000;
const MAX_ITEMS_PER_SOURCE = 15;
const TTL_HOURS = 24 * 30;

const parser = new Parser({
  timeout: PARSE_TIMEOUT_MS,
  headers: {
    "User-Agent": "Faro-NewsIngest/0.1 (+https://github.com/Maufloquet/faro)",
  },
});

exports.ingestNewsBahia = onSchedule(
  {
    schedule: "every 30 minutes",
    timeZone: "America/Bahia",
    region: "southamerica-east1",
    memory: "512MiB",
    timeoutSeconds: 300,
    secrets: ["GROQ_API_KEY"],
  },
  async () => {
    const db = admin.firestore();
    const sources = enabledSources();
    const stats = {
      sourcesActive: sources.length,
      itemsFetched: 0,
      itemsNew: 0,
      itemsClassified: 0,
      itemsWritten: 0,
      itemsSkipped: 0,
      errors: 0,
    };

    for (const source of sources) {
      try {
        const result = await ingestFromSource(db, source);
        stats.itemsFetched += result.fetched;
        stats.itemsNew += result.newItems;
        stats.itemsClassified += result.classified;
        stats.itemsWritten += result.written;
        stats.itemsSkipped += result.skipped;
      } catch (e) {
        stats.errors++;
        logger.error(`Falha em ${source.id}: ${e.message}`, { source: source.id });
      }
    }

    logger.info("Ingest news concluído", stats);
  }
);

async function ingestFromSource(db, source) {
  const fetched = await parser.parseURL(source.url);
  const items = (fetched.items || []).slice(0, MAX_ITEMS_PER_SOURCE);

  const result = { fetched: items.length, newItems: 0, classified: 0, written: 0, skipped: 0 };

  for (const item of items) {
    const url = item.link;
    if (!url) {
      result.skipped++;
      continue;
    }

    const hash = sha1(url);
    const seenRef = db.collection("news_seen").doc(hash);
    const seenDoc = await seenRef.get();
    if (seenDoc.exists) {
      result.skipped++;
      continue;
    }
    result.newItems++;

    // Marca como visto ANTES de classificar — evita reprocessar em caso
    // de timeout depois. Pior caso: pulamos um item que poderia ser válido.
    await seenRef.set({
      source: source.id,
      url,
      title: item.title || "",
      seenAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    let classification;
    try {
      classification = await classify(item.title || "", item.contentSnippet || item.content || "");
      result.classified++;
    } catch (e) {
      logger.warn(`Classificação falhou pra ${url}: ${e.message}`);
      continue;
    }

    if (!classification.security_related) continue;
    if (!classification.neighborhood) continue;
    if ((classification.confidence ?? 0) < 0.55) continue;
    if (classification.city && !classification.city.toLowerCase().includes("salvador")) continue;

    const geo = resolveBairro(classification.neighborhood);
    if (!geo) {
      logger.info(`Bairro \"${classification.neighborhood}\" não resolvido localmente`);
      continue;
    }

    // ID determinístico do doc: hash do URL — idempotente.
    const docId = `media-${hash.slice(0, 16)}`;
    const pubDate = item.isoDate ? new Date(item.isoDate) : new Date();
    const expiresAt = new Date(pubDate.getTime() + TTL_HOURS * 60 * 60 * 1000);

    await db.collection("occurrences").doc(docId).set(
      {
        latitude: geo.lat,
        longitude: geo.lng,
        geohash: ngeohash.encode(geo.lat, geo.lng, 8),
        date: admin.firestore.Timestamp.fromDate(pubDate),
        expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
        state: "Bahia",
        city: "Salvador",
        neighborhood: geo.matched,
        mainReason: mapType(classification.occurrence_type),
        source: SOURCE,
        sourceProvider: source.id,
        sourceName: source.name,
        weight: source.weight,
        externalUrl: url,
        externalTitle: item.title,
        confidence: classification.confidence,
        geocodeMethod: geo.method,
        ingestedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
    result.written++;
  }

  logger.info(`${source.id}: fetched=${result.fetched} new=${result.newItems} written=${result.written}`);
  return result;
}

function sha1(s) {
  return crypto.createHash("sha1").update(s).digest("hex");
}

const TYPE_MAP = {
  tiroteio: "Tiroteio",
  homicidio: "Homicídio",
  roubo: "Roubo",
  acao_policial: "Ação policial",
  sequestro: "Sequestro",
  agressao: "Agressão",
  outros: "Outros",
};

function mapType(t) {
  if (!t) return "Outros";
  return TYPE_MAP[t.toLowerCase()] || "Outros";
}
