"use strict";

/**
 * Cache de token JWT do Fogo Cruzado.
 *
 * Tokens duram 3600s. Cacheamos em memória e renovamos antes do vencimento.
 * Em produção, considerar mover para Secret Manager ou cache compartilhado
 * se múltiplas instâncias começarem a duplicar requests de auth.
 */

const BASE_URL = "https://api-service.fogocruzado.org.br/api/v2";

let tokenCache = { token: null, expiresAt: 0 };

async function getToken() {
  const now = Date.now();
  if (tokenCache.token && tokenCache.expiresAt > now + 60_000) {
    return tokenCache.token;
  }

  const email = process.env.FOGO_CRUZADO_EMAIL;
  const password = process.env.FOGO_CRUZADO_PASSWORD;
  if (!email || !password) {
    throw new Error("FOGO_CRUZADO_EMAIL e FOGO_CRUZADO_PASSWORD são obrigatórios no env");
  }

  const r = await fetch(`${BASE_URL}/auth/login`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ email, password }),
  });
  if (!r.ok) {
    const body = await r.text();
    throw new Error(`Fogo Cruzado auth ${r.status}: ${body.slice(0, 200)}`);
  }
  const data = await r.json();
  const expiresIn = (data.data.expiresIn || 3600) * 1000;
  tokenCache = {
    token: data.data.accessToken,
    expiresAt: now + expiresIn,
  };
  return tokenCache.token;
}

async function authedFetch(path, params = {}) {
  const token = await getToken();
  const url = new URL(`${BASE_URL}${path}`);
  for (const [k, v] of Object.entries(params)) {
    if (v !== undefined && v !== null) url.searchParams.set(k, String(v));
  }
  const r = await fetch(url.toString(), {
    headers: { Authorization: `Bearer ${token}` },
  });
  if (!r.ok) {
    const body = await r.text();
    throw new Error(`Fogo Cruzado ${path} ${r.status}: ${body.slice(0, 200)}`);
  }
  return r.json();
}

module.exports = { BASE_URL, getToken, authedFetch };
