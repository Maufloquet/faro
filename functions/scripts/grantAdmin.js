#!/usr/bin/env node
/**
 * Concede o custom claim `admin: true` a um usuário do Faro.
 *
 * Custom claims viajam dentro do ID token JWT. Quando o app refaz
 * o login (ou força refresh), o claim entra no token e as Firestore
 * rules conseguem ler via `request.auth.token.admin`.
 *
 * Uso:
 *   gcloud auth application-default login
 *   node scripts/grantAdmin.js <uid>
 *   node scripts/grantAdmin.js <uid> --revoke
 *
 * Pra descobrir o UID:
 *   1. Logue no app com sua conta Google.
 *   2. Console Firebase → Authentication → Users → copie o User UID.
 *
 * Depois de rodar: feche e reabra o app pra forçar refresh do token,
 * ou aguarde até 1h (TTL natural do token Firebase).
 */

"use strict";

const admin = require("firebase-admin");

if (!admin.apps.length) {
  admin.initializeApp({ projectId: "faro-f3472" });
}

async function main() {
  const args = process.argv.slice(2);
  const uid = args.find((a) => !a.startsWith("--"));
  const revoke = args.includes("--revoke");

  if (!uid) {
    console.error("Uso: node scripts/grantAdmin.js <uid> [--revoke]");
    process.exit(1);
  }

  const user = await admin.auth().getUser(uid);
  console.log(`Usuário encontrado: ${user.email || "(sem email)"} — uid=${user.uid}`);

  const existing = user.customClaims || {};
  const next = { ...existing };
  if (revoke) {
    delete next.admin;
  } else {
    next.admin = true;
  }

  await admin.auth().setCustomUserClaims(uid, next);
  console.log(`Claims atualizados: ${JSON.stringify(next)}`);
  console.log("Pra ver efeito imediato no app: faça logout e login novamente.");
}

main()
  .then(() => process.exit(0))
  .catch((e) => {
    console.error(e);
    process.exit(1);
  });
