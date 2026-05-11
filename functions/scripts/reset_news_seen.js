#!/usr/bin/env node
/**
 * Limpa a collection news_seen — usado quando uma rodada de classificação
 * marcou items como vistos sem conseguir processar (ex: rate limit).
 *
 * Uso:
 *   GOOGLE_APPLICATION_CREDENTIALS=path/to/sa.json node scripts/reset_news_seen.js
 *
 * OU dentro do projeto faro-f3472 já autenticado:
 *   gcloud auth application-default login
 *   node scripts/reset_news_seen.js
 */

const admin = require("firebase-admin");

if (!admin.apps.length) {
  admin.initializeApp({ projectId: "faro-f3472" });
}

const db = admin.firestore();

async function main() {
  console.log("Lendo news_seen…");
  const snap = await db.collection("news_seen").get();
  console.log(`Total a deletar: ${snap.size}`);
  if (snap.empty) {
    console.log("Já está vazio.");
    return;
  }

  // Firestore bulkWriter pra eficiência
  const writer = db.bulkWriter();
  for (const doc of snap.docs) {
    writer.delete(doc.ref);
  }
  await writer.close();
  console.log("Limpeza concluída.");
}

main()
  .then(() => process.exit(0))
  .catch((e) => {
    console.error(e);
    process.exit(1);
  });
