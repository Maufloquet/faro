"use strict";

/**
 * Backfill de deduplicação — one-shot, manual.
 *
 * Roda sobre /occurrences procurando duplicatas (mesma eventKey dentro de
 * janela ±6h) que já estão gravadas. Pra cada grupo:
 *   - escolhe o doc mais antigo como canônico (preserva a primeira evidência)
 *   - mescla os demais como corroborations no canônico (cap de peso)
 *   - deleta os duplicados
 *
 * Idempotente: docs já mesclados (sem eventKey ou com corroborationCount já
 * presente) não entram em novos grupos só por estarem isolados.
 *
 * Modo dry-run: ?dryRun=true só relata o que faria, sem escrever nada.
 *
 * Como invocar (admin do projeto, invoker=private por default):
 *   curl -X POST -H "Authorization: Bearer <token>" "<function-url>?dryRun=true"
 *   curl -X POST -H "Authorization: Bearer <token>" "<function-url>"
 *
 * Custo: 1 read full-collection + N writes (delete + update). Pra ~5k docs
 * de Salvador é alguns centavos.
 */

const admin = require("firebase-admin");
const { onRequest } = require("firebase-functions/v2/https");
const { logger } = require("firebase-functions/v2");

const DEDUP_WINDOW_HOURS = 6;
const CORROBORATION_WEIGHT_BOOST = 0.05;
const MAX_CORROBORATED_WEIGHT = 0.95;
const MAX_DOCS_PER_RUN = 10000; // cap defensivo

/**
 * Agrupa uma lista de docs em (canônico, duplicates).
 *
 * Pré-requisito: cada item tem { id, eventKey, dateMs, source, ... }.
 * Docs sem eventKey são ignorados (não agrupáveis).
 *
 * Algoritmo:
 *   1. Ordena por (eventKey ASC, dateMs ASC)
 *   2. Janela deslizante a partir do canônico: tudo dentro de windowMs
 *      a partir do canônico vai pro mesmo grupo. Fora disso, novo grupo.
 *
 * @param {Array<{id:string, eventKey:string|null, dateMs:number}>} items
 * @param {number} windowHours
 * @returns {Array<{canonical: object, duplicates: object[]}>}
 */
function groupDuplicates(items, windowHours = DEDUP_WINDOW_HOURS) {
  const windowMs = windowHours * 60 * 60 * 1000;
  const indexable = items.filter((it) => it && it.eventKey);

  indexable.sort((a, b) => {
    if (a.eventKey !== b.eventKey) return a.eventKey < b.eventKey ? -1 : 1;
    if (a.dateMs !== b.dateMs) return a.dateMs - b.dateMs;
    return a.id < b.id ? -1 : a.id > b.id ? 1 : 0;
  });

  const groups = [];
  for (const doc of indexable) {
    const last = groups[groups.length - 1];
    const fitsCurrent =
      last &&
      last.canonical.eventKey === doc.eventKey &&
      doc.dateMs - last.canonical.dateMs <= windowMs;

    if (fitsCurrent) {
      last.duplicates.push(doc);
    } else {
      groups.push({ canonical: doc, duplicates: [] });
    }
  }
  return groups;
}

/**
 * Constrói o objeto de corroboração a partir de um doc duplicado.
 * Source-agnostic: trata media e fogo_cruzado.
 */
function buildCorroboration(doc) {
  const c = {
    source: doc.source || "unknown",
    addedAt: new Date(),
  };
  if (doc.sourceProvider) c.sourceProvider = doc.sourceProvider;
  if (doc.sourceName) c.sourceName = doc.sourceName;
  if (doc.externalUrl) c.url = doc.externalUrl;
  if (doc.externalTitle) c.title = doc.externalTitle;
  if (doc.externalId) c.externalId = doc.externalId;
  if (typeof doc.confidence === "number") c.confidence = doc.confidence;
  if (doc.mainReason) c.mainReason = doc.mainReason;
  return c;
}

exports.backfillDedup = onRequest(
  {
    region: "southamerica-east1",
    memory: "512MiB",
    timeoutSeconds: 540,
    // invoker: "private" por default — só admins do projeto.
  },
  async (req, res) => {
    const dryRun = req.query.dryRun === "true";
    const db = admin.firestore();

    const snap = await db
      .collection("occurrences")
      .limit(MAX_DOCS_PER_RUN)
      .get();

    const items = [];
    for (const doc of snap.docs) {
      const d = doc.data();
      const dateMs = d.date?.toMillis?.() ?? 0;
      items.push({
        id: doc.id,
        ref: doc.ref,
        eventKey: d.eventKey || null,
        dateMs,
        source: d.source,
        weight: typeof d.weight === "number" ? d.weight : 0.5,
        sourceProvider: d.sourceProvider || null,
        sourceName: d.sourceName || null,
        externalUrl: d.externalUrl || null,
        externalTitle: d.externalTitle || null,
        externalId: d.externalId || null,
        confidence: typeof d.confidence === "number" ? d.confidence : null,
        mainReason: d.mainReason || null,
        expiresMs: d.expiresAt?.toMillis?.() ?? 0,
        corroborationCount: d.corroborationCount || 0,
      });
    }

    const groups = groupDuplicates(items, DEDUP_WINDOW_HOURS);
    const groupsWithDupes = groups.filter((g) => g.duplicates.length > 0);

    const stats = {
      dryRun,
      totalDocsScanned: items.length,
      docsWithoutEventKey: items.filter((i) => !i.eventKey).length,
      groupsFound: groups.length,
      groupsWithDuplicates: groupsWithDupes.length,
      duplicatesMerged: 0,
      duplicatesDeleted: 0,
    };

    if (dryRun) {
      stats.samples = groupsWithDupes.slice(0, 5).map((g) => ({
        eventKey: g.canonical.eventKey,
        canonical: g.canonical.id,
        duplicates: g.duplicates.map((d) => d.id),
      }));
      logger.info("Dedup backfill (dry-run)", stats);
      res.status(200).json(stats);
      return;
    }

    for (const g of groupsWithDupes) {
      const canonicalRef = g.canonical.ref;
      const corroborations = g.duplicates.map(buildCorroboration);

      // Peso novo: boost por cada duplicata absorvida, capeado.
      const boosted = Math.min(
        MAX_CORROBORATED_WEIGHT,
        (g.canonical.weight || 0.5) +
          g.duplicates.length * CORROBORATION_WEIGHT_BOOST,
      );

      // ExpiresAt: o mais distante entre canônico e duplicatas
      // (preserva visibilidade pelo maior tempo).
      const maxExpiresMs = Math.max(
        g.canonical.expiresMs || 0,
        ...g.duplicates.map((d) => d.expiresMs || 0),
      );

      await canonicalRef.update({
        corroborations: admin.firestore.FieldValue.arrayUnion(...corroborations),
        corroborationCount: admin.firestore.FieldValue.increment(
          g.duplicates.length,
        ),
        weight: boosted,
        expiresAt: admin.firestore.Timestamp.fromMillis(maxExpiresMs),
        lastCorroboratedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      stats.duplicatesMerged += g.duplicates.length;

      const writer = db.bulkWriter();
      for (const dup of g.duplicates) {
        writer.delete(dup.ref);
      }
      await writer.close();
      stats.duplicatesDeleted += g.duplicates.length;
    }

    logger.info("Dedup backfill concluído", stats);
    res.status(200).json(stats);
  },
);

exports._internal = { groupDuplicates, buildCorroboration, DEDUP_WINDOW_HOURS };
