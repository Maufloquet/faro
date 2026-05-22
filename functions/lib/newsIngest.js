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
const { stateForCity } = require("./cityCentroids");
const { buildEventKey } = require("./eventKey");

const STATE_NAME_BY_UF = {
  BA: "Bahia",
  RJ: "Rio de Janeiro",
  PE: "Pernambuco",
  SP: "São Paulo",
};

const SOURCE = "media";
const PARSE_TIMEOUT_MS = 15000;
// Reduzido pra 8 — com 12 fontes ativas, são ~96 items/run. Margem
// confortável dentro do TPM do Groq 8B (30k/min) sem retry agressivo.
const MAX_ITEMS_PER_SOURCE = 8;
const TTL_HOURS = 24 * 30;

/** Janela de ±N horas em que dois relatos do mesmo (cidade, bairro, tipo)
 * são tratados como o MESMO evento e merged como corroboração. */
const DEDUP_WINDOW_HOURS = 6;

/** Boost de peso por corroboração — saiu em mais um veículo, sobe um pouco.
 * Cap evita que evento megamidiático domine o score indefinidamente. */
const CORROBORATION_WEIGHT_BOOST = 0.05;
const MAX_CORROBORATED_WEIGHT = 0.95;

// Parser instanciado lazy dentro da função pra não pesar o load global
// — firebase tenta importar o módulo em 10s pra descobrir as functions.
let _parser = null;
function getParser() {
  if (_parser) return _parser;
  _parser = new Parser({
    timeout: PARSE_TIMEOUT_MS,
    headers: {
      "User-Agent": "Faro-NewsIngest/0.1 (+https://github.com/Maufloquet/faro)",
    },
  });
  return _parser;
}

exports.ingestNewsBahia = onSchedule(
  {
    schedule: "every 30 minutes",
    timeZone: "America/Bahia",
    region: "southamerica-east1",
    memory: "512MiB",
    timeoutSeconds: 540,
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

    // Processamento em chunks paralelos. 24+ sources em série encostava
    // no timeout de 540s quando Groq ficava lento. Chunks de 4 sources
    // simultâneas limitam pico de paralelismo no Groq (8 items × 4 srcs =
    // ~32 calls em pico curto) e ainda cortam o wall time em ~4x.
    const CONCURRENCY = 4;
    for (let i = 0; i < sources.length; i += CONCURRENCY) {
      const chunk = sources.slice(i, i + CONCURRENCY);
      const results = await Promise.allSettled(
        chunk.map((source) => ingestFromSource(db, source))
      );
      for (let j = 0; j < results.length; j++) {
        const r = results[j];
        const source = chunk[j];
        if (r.status === "fulfilled") {
          stats.itemsFetched += r.value.fetched;
          stats.itemsNew += r.value.newItems;
          stats.itemsClassified += r.value.classified;
          stats.itemsWritten += r.value.written;
          stats.itemsSkipped += r.value.skipped;
        } else {
          stats.errors++;
          logger.error(`Falha em ${source.id}: ${r.reason?.message || r.reason}`, {
            source: source.id,
          });
        }
      }
    }

    logger.info("Ingest news concluído", stats);
  }
);

async function ingestFromSource(db, source) {
  const fetched = await getParser().parseURL(source.url);
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

    let classification;
    try {
      classification = await classify(item.title || "", item.contentSnippet || item.content || "");
      result.classified++;
    } catch (e) {
      // NÃO marca como visto — vamos tentar de novo no próximo run.
      // Se a falha for transiente (rate limit, instabilidade), recuperamos.
      // Se for permanente (URL inválida), no máximo loga ruído extra.
      logger.warn(`Classificação falhou pra ${url}: ${e.message}`);
      continue;
    }

    // Helper local: marca o item como visto. Chamado em 2 cenários:
    //  (a) descarte por filtro — já gastamos classificação, não vale
    //      reclassificar no próximo run.
    //  (b) escrita em /occurrences ok — sucesso do pipeline.
    // O que NÃO faz seen: falha de escrita em Firestore. Aí o item
    // volta no próximo run pra retentativa (custa Groq de novo, mas
    // evita perda silenciosa como aconteceu no bug do índice em 18/05).
    const markSeen = () => seenRef.set({
      source: source.id,
      url,
      title: item.title || "",
      seenAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    if (!classification.security_related) { await markSeen(); continue; }
    if ((classification.confidence ?? 0) < 0.55) { await markSeen(); continue; }
    // Cidade tem que ser uma das 4 cobertas. resolveBairro depois trata
    // o caso de bairro ausente caindo no centroide.
    if (!classification.city) { await markSeen(); continue; }

    const geo = resolveBairro(classification.neighborhood, classification.city);
    if (!geo) {
      logger.info(
        `Não resolvido: bairro=\"${classification.neighborhood}\" cidade=\"${classification.city}\"`
      );
      await markSeen();
      continue;
    }

    const pubDate = item.isoDate ? new Date(item.isoDate) : new Date();
    const expiresAt = new Date(pubDate.getTime() + TTL_HOURS * 60 * 60 * 1000);
    const mainReason = mapType(classification.occurrence_type);
    const neighborhood = geo.method === "city-centroid" ? null : geo.matched;
    const busLines = sanitizeBusLines(classification.bus_lines);
    const transportContext = sanitizeTransportContext(classification.transport_context);
    const eventKey = buildEventKey({
      city: classification.city,
      neighborhood,
      mainReason,
      geocodeMethod: geo.method,
    });

    // Dedupe cross-source: se já existe doc com mesma eventKey em ±6h,
    // adicionamos uma corroboração em vez de criar duplicata. Cobre
    // "mesmo tiroteio sai em 3 portais" e "Fogo Cruzado + matéria sobre
    // o mesmo evento".
    const corroboration = {
      source: SOURCE,
      sourceProvider: source.id,
      sourceName: source.name,
      url,
      title: item.title || null,
      confidence: classification.confidence ?? null,
      addedAt: new Date(),
    };

    const existing = eventKey ? await findCorroboratableDoc(db, eventKey, pubDate) : null;
    if (existing) {
      const data = existing.data();
      const currentWeight = typeof data.weight === "number" ? data.weight : 0.5;
      await existing.ref.update({
        corroborations: admin.firestore.FieldValue.arrayUnion(corroboration),
        corroborationCount: admin.firestore.FieldValue.increment(1),
        weight: Math.min(MAX_CORROBORATED_WEIGHT, currentWeight + CORROBORATION_WEIGHT_BOOST),
        // expira não antes da janela do relato mais recente.
        expiresAt: admin.firestore.Timestamp.fromDate(
          new Date(Math.max(
            data.expiresAt?.toMillis?.() ?? 0,
            expiresAt.getTime(),
          )),
        ),
        lastCorroboratedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      logger.info(`Corroborado · ${existing.id} += ${source.id}`);
      result.written++;
      await markSeen();
      continue;
    }

    // ID determinístico do doc: hash do URL — idempotente.
    const docId = `media-${hash.slice(0, 16)}`;

    const uf = stateForCity(geo.cityKey);
    const stateLabel = STATE_NAME_BY_UF[uf] || uf || "Bahia";

    await db.collection("occurrences").doc(docId).set(
      {
        latitude: geo.lat,
        longitude: geo.lng,
        geohash: ngeohash.encode(geo.lat, geo.lng, 8),
        date: admin.firestore.Timestamp.fromDate(pubDate),
        expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
        state: stateLabel,
        city: classification.city,
        neighborhood,
        geocodeMethod: geo.method,
        mainReason,
        eventKey,
        busLines,
        transportContext,
        source: SOURCE,
        sourceProvider: source.id,
        sourceName: source.name,
        weight: source.weight,
        externalUrl: url,
        externalTitle: item.title,
        confidence: classification.confidence,
        corroborationCount: 0,
        ingestedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
    result.written++;
    await markSeen();
  }

  logger.info(`${source.id}: fetched=${result.fetched} new=${result.newItems} written=${result.written}`);
  return result;
}

function sha1(s) {
  return crypto.createHash("sha1").update(s).digest("hex");
}

/**
 * Procura por um doc em /occurrences com a mesma eventKey dentro de
 * ±DEDUP_WINDOW_HOURS da data passada. Retorna o DocumentSnapshot ou null.
 * A query precisa do índice composto (eventKey ASC, date ASC).
 */
async function findCorroboratableDoc(db, eventKey, pubDate) {
  if (!eventKey) return null;
  const windowMs = DEDUP_WINDOW_HOURS * 60 * 60 * 1000;
  const since = new Date(pubDate.getTime() - windowMs);
  const until = new Date(pubDate.getTime() + windowMs);
  const snap = await db
    .collection("occurrences")
    .where("eventKey", "==", eventKey)
    .where("date", ">=", admin.firestore.Timestamp.fromDate(since))
    .where("date", "<=", admin.firestore.Timestamp.fromDate(until))
    .limit(1)
    .get();
  return snap.empty ? null : snap.docs[0];
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

/**
 * Aceita 2 formatos de linha que a IA consegue extrair com confiança:
 *
 *   (A) **Códigos numéricos** — `"1234"`, `"L-105"`, `"0220-01"`
 *       Tem dígito + apenas `[A-Za-z0-9.-/]`, sem espaços.
 *
 *   (B) **Linha nomeada por origem-destino** — `"Cajazeiras-Lapa"`,
 *       `"Pituba/Rodoviária"`, `"Itinga / Praça da Sé"`
 *       Tem separador `-` ou `/`, pelo menos 2 tokens com ≥ 3 letras,
 *       só letras (incluindo acentuadas) + espaços.
 *
 * Bloqueia descrições livres ("ônibus pra Lauro", "linha 1234, sentido X"),
 * nomes únicos ("Pituba"), e strings longas (> 40 chars).
 *
 * A IA recebe regras compatíveis no prompt (groqClient.js).
 */
function sanitizeBusLines(raw) {
  if (!Array.isArray(raw)) return [];
  const seen = new Set();
  const out = [];
  for (const v of raw) {
    if (typeof v !== "string") continue;
    const trimmed = v.trim().replace(/\s+/g, " "); // normaliza espaços duplos
    if (trimmed.length === 0 || trimmed.length > 40) continue;
    if (!isValidBusLineFormat(trimmed)) continue;
    // Códigos puros vão pra UPPER ("l-105" → "L-105"); nomes mantêm o
    // case original ("Cajazeiras-Lapa"). Código = tem dígito + chars
    // compactos. Sem dígito (linha nomeada) preserva o casing.
    const isCode =
      /\d/.test(trimmed) && /^[A-Za-z0-9.\-/]+$/.test(trimmed);
    const norm = isCode ? trimmed.toUpperCase() : trimmed;
    const dedupKey = norm.toLowerCase();
    if (seen.has(dedupKey)) continue;
    seen.add(dedupKey);
    out.push(norm);
  }
  return out;
}

function isValidBusLineFormat(s) {
  // (A) Código: contém dígito + apenas chars compactos permitidos.
  if (/\d/.test(s) && /^[A-Za-z0-9.\-/]+$/.test(s)) return true;

  // (B) Linha nomeada origem-destino: separador `-` ou `/`, só letras
  //     (com acentos) e espaços. Tokens com ≥ 3 letras cada, ≥ 2 tokens.
  if (/[-/]/.test(s) && /^[\p{L} \-/]+$/u.test(s)) {
    const tokens = s.split(/[-/]/).map((t) => t.trim()).filter(Boolean);
    if (tokens.length < 2) return false;
    return tokens.every((t) => t.replace(/\s/g, "").length >= 3);
  }

  return false;
}

function sanitizeTransportContext(raw) {
  if (raw === "onibus" || raw === "metro") return raw;
  return null;
}

// Exportado para testes unitários
exports._internal = {
  sha1,
  mapType,
  TYPE_MAP,
  findCorroboratableDoc,
  DEDUP_WINDOW_HOURS,
  CORROBORATION_WEIGHT_BOOST,
  MAX_CORROBORATED_WEIGHT,
  sanitizeBusLines,
  sanitizeTransportContext,
};
