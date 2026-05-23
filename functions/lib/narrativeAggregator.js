"use strict";

/**
 * Clustering semanal de ocorrências em "narrativas" — feature editorial
 * que faltava no Faro.
 *
 * Hoje a UI mostra eventos isolados. Quando 6 relatos diferentes em 3
 * bairros vizinhos descrevem o mesmo padrão (onda de assaltos numa rua,
 * série de tiroteios numa madrugada), nada amarra. Esta função amarra:
 * agrupa por similaridade de embedding + cidade comum, escreve em
 * `/narratives/{id}` com copy editorial pré-gerado.
 *
 * Tom: nunca veredito. "Esta semana — 6 relatos relacionados em Garcia."
 * Aparece NA UI como contexto, com link pros relatos originais.
 *
 * Algoritmo: greedy single-link agglomerative com threshold de
 * similaridade. O(n²) é OK enquanto a janela for 7d (esperado < 1k docs).
 * Quando crescer, migra pra DBSCAN com índice vetorial.
 *
 * Scheduler diário 04:00 (depois do `aggregateHistoricalBaseline` 03:30,
 * antes do horário comercial). Idempotente: re-rodar sobrescreve as
 * narrativas com snapshot atual; narrativas que perdem força (semana
 * passa, ocorrências expiram) são removidas no próximo run.
 */

const admin = require("firebase-admin");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { logger } = require("firebase-functions/v2");

const { runWithHealth } = require("./jobHealth");

const WINDOW_DAYS = 7;
const MIN_CLUSTER_SIZE = 3;
const SIMILARITY_THRESHOLD = 0.80; // cosseno mínimo pra agrupar
const SAMPLE_SIZE = 3;
const MAX_REASONS = 3;

exports.aggregateNarratives = onSchedule(
  {
    schedule: "every day 04:00",
    timeZone: "America/Bahia",
    region: "southamerica-east1",
    memory: "512MiB",
    timeoutSeconds: 300,
  },
  async () => runWithHealth("aggregateNarratives", async () => {
    const db = admin.firestore();
    const now = new Date();
    const since = new Date(now.getTime() - WINDOW_DAYS * 24 * 60 * 60 * 1000);

    const snap = await db
      .collection("occurrences")
      .where("date", ">=", admin.firestore.Timestamp.fromDate(since))
      .get();

    const items = [];
    snap.forEach((doc) => {
      const data = doc.data();
      const vec = extractVector(data.embedding);
      if (!vec) return;
      items.push({
        id: doc.id,
        city: data.city || null,
        neighborhood: data.neighborhood || null,
        mainReason: data.mainReason || null,
        date: data.date && data.date.toDate ? data.date.toDate() : null,
        externalTitle: data.externalTitle || null,
        embedding: vec,
      });
    });

    const clusters = clusterItems(items, {
      similarityThreshold: SIMILARITY_THRESHOLD,
      minSize: MIN_CLUSTER_SIZE,
    });

    // Apaga narrativas obsoletas: pega tudo em /narratives, depois deleta
    // o que não veio do run atual. Snapshot semanal, sem histórico.
    const oldSnap = await db.collection("narratives").get();
    const newIds = new Set(clusters.map((c) => narrativeId(c)));
    const batch = db.batch();
    for (const doc of oldSnap.docs) {
      if (!newIds.has(doc.id)) batch.delete(doc.ref);
    }

    for (const cluster of clusters) {
      const id = narrativeId(cluster);
      const ref = db.collection("narratives").doc(id);
      const payload = buildNarrativePayload(cluster);
      batch.set(ref, {
        ...payload,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();

    logger.info(
      `narratives: ${items.length} docs com embedding → ${clusters.length} narrativas (>= ${MIN_CLUSTER_SIZE})`,
    );
    return { itemsWritten: clusters.length };
  }),
);

/**
 * Clustering greedy. Pra cada item, encontra cluster cuja similaridade
 * com o centroide é máxima E acima do threshold E mesma cidade. Se
 * encontrar, agrega; se não, abre cluster novo.
 *
 * Função pura — testável sem Firestore.
 */
function clusterItems(items, opts) {
  const { similarityThreshold, minSize } = opts;
  const clusters = [];
  for (const item of items) {
    let bestIdx = -1;
    let bestSim = -1;
    for (let i = 0; i < clusters.length; i++) {
      const c = clusters[i];
      // Só agrega se cidade bate. Cidade null vira "cidade desconhecida"
      // e ficam no seu próprio grupo — não misturamos com bairros reais.
      if (c.city !== item.city) continue;
      const sim = cosineSimilarity(c.centroid, item.embedding);
      if (sim > bestSim) {
        bestSim = sim;
        bestIdx = i;
      }
    }
    if (bestIdx >= 0 && bestSim >= similarityThreshold) {
      addToCluster(clusters[bestIdx], item);
    } else {
      clusters.push(seedCluster(item));
    }
  }
  return clusters.filter((c) => c.items.length >= minSize);
}

function seedCluster(item) {
  return {
    city: item.city,
    centroid: [...item.embedding],
    items: [item],
    neighborhoods: new Set(item.neighborhood ? [item.neighborhood] : []),
    reasonCount: incrementMap(new Map(), item.mainReason),
    firstSeenAt: item.date,
    lastSeenAt: item.date,
  };
}

function addToCluster(cluster, item) {
  const n = cluster.items.length;
  // Atualiza centroide incrementalmente — média ponderada.
  for (let i = 0; i < cluster.centroid.length; i++) {
    cluster.centroid[i] = (cluster.centroid[i] * n + item.embedding[i]) / (n + 1);
  }
  cluster.items.push(item);
  if (item.neighborhood) cluster.neighborhoods.add(item.neighborhood);
  incrementMap(cluster.reasonCount, item.mainReason);
  if (item.date) {
    if (!cluster.firstSeenAt || item.date < cluster.firstSeenAt) {
      cluster.firstSeenAt = item.date;
    }
    if (!cluster.lastSeenAt || item.date > cluster.lastSeenAt) {
      cluster.lastSeenAt = item.date;
    }
  }
}

function incrementMap(map, key) {
  if (!key) return map;
  map.set(key, (map.get(key) || 0) + 1);
  return map;
}

function buildNarrativePayload(cluster) {
  const neighborhoods = Array.from(cluster.neighborhoods).sort();
  const topReasons = Array.from(cluster.reasonCount.entries())
    .sort((a, b) => b[1] - a[1])
    .slice(0, MAX_REASONS)
    .map(([reason, count]) => ({ reason, count }));

  // Sample: 3 mais recentes (mais relevantes pro usuário ler depois).
  const sample = [...cluster.items]
    .sort((a, b) => (b.date?.getTime() || 0) - (a.date?.getTime() || 0))
    .slice(0, SAMPLE_SIZE)
    .map((it) => ({
      id: it.id,
      externalTitle: it.externalTitle,
      neighborhood: it.neighborhood,
      mainReason: it.mainReason,
    }));

  return {
    city: cluster.city,
    neighborhoods,
    count: cluster.items.length,
    topReasons,
    sample,
    firstSeenAt: cluster.firstSeenAt
      ? admin.firestore.Timestamp.fromDate(cluster.firstSeenAt)
      : null,
    lastSeenAt: cluster.lastSeenAt
      ? admin.firestore.Timestamp.fromDate(cluster.lastSeenAt)
      : null,
    headline: editorialHeadline(cluster, neighborhoods, topReasons),
    windowDays: WINDOW_DAYS,
  };
}

/**
 * Copy editorial pré-gerada. Sem palavras alarmistas. Quando há um único
 * bairro, foca nele; quando vários, fala em "região". Quando o motivo
 * predominante representa >= 60% das ocorrências, cita; caso contrário
 * fica em "relatos relacionados".
 */
function editorialHeadline(cluster, neighborhoods, topReasons) {
  const count = cluster.items.length;
  const where =
    neighborhoods.length === 0
      ? cluster.city || "região"
      : neighborhoods.length === 1
      ? neighborhoods[0]
      : `região de ${neighborhoods.slice(0, 2).join(" e ")}`;

  const dominant = topReasons[0];
  const dominantShare = dominant ? dominant.count / count : 0;
  if (dominant && dominantShare >= 0.6) {
    return `Esta semana — ${count} relatos relacionados a ${dominant.reason.toLowerCase()} em ${where}.`;
  }
  return `Esta semana — ${count} relatos relacionados em ${where}.`;
}

function narrativeId(cluster) {
  const citySlug = slug(cluster.city || "_");
  const bairroSlug = slug(
    Array.from(cluster.neighborhoods).sort().join("-") || "_",
  );
  return `${citySlug}__${bairroSlug}`;
}

function slug(s) {
  return String(s || "_")
    .toLowerCase()
    .normalize("NFD")
    .replace(/[̀-ͯ]/g, "")
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-|-$/g, "") || "_";
}

/**
 * Aceita tanto Float32Array (raro) quanto o tipo `VectorValue` do
 * Firestore. O VectorValue tem `.toArray()`; outros casos caem em null.
 */
function extractVector(v) {
  if (!v) return null;
  if (typeof v.toArray === "function") {
    const arr = v.toArray();
    return Array.isArray(arr) || ArrayBuffer.isView(arr) ? Array.from(arr) : null;
  }
  if (Array.isArray(v)) return v;
  return null;
}

function cosineSimilarity(a, b) {
  let dot = 0;
  let na = 0;
  let nb = 0;
  for (let i = 0; i < a.length; i++) {
    dot += a[i] * b[i];
    na += a[i] * a[i];
    nb += b[i] * b[i];
  }
  if (na === 0 || nb === 0) return 0;
  return dot / (Math.sqrt(na) * Math.sqrt(nb));
}

exports._internal = {
  clusterItems,
  cosineSimilarity,
  editorialHeadline,
  narrativeId,
};
