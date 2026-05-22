"use strict";

/**
 * Cache de token JWT do Fogo Cruzado.
 *
 * Tokens duram 3600s. Cacheamos em memória e renovamos antes do vencimento.
 * Em produção, considerar mover para Secret Manager ou cache compartilhado
 * se múltiplas instâncias começarem a duplicar requests de auth.
 */

const BASE_URL = "https://api-service.fogocruzado.org.br/api/v2";

// Margem de 5 minutos antes do vencimento. Acima de 60s pra evitar que
// duas instâncias do scheduler iniciem login quase ao mesmo tempo quando
// o token está pra expirar — cada uma carrega o cache em memória própria.
const TOKEN_REFRESH_MARGIN_MS = 5 * 60_000;

// Retry: falhas de rede e 5xx são tratadas como transientes. 4xx não retry
// (erro do cliente — bad input, auth ruim — não vai melhorar com retry).
const MAX_RETRIES = 3;
const BASE_BACKOFF_MS = 500;

let tokenCache = { token: null, expiresAt: 0 };

async function getToken() {
  const now = Date.now();
  if (tokenCache.token && tokenCache.expiresAt > now + TOKEN_REFRESH_MARGIN_MS) {
    return tokenCache.token;
  }

  const email = process.env.FOGO_CRUZADO_EMAIL;
  const password = process.env.FOGO_CRUZADO_PASSWORD;
  if (!email || !password) {
    throw new Error("FOGO_CRUZADO_EMAIL e FOGO_CRUZADO_PASSWORD são obrigatórios no env");
  }

  const r = await fetchWithRetry(`${BASE_URL}/auth/login`, {
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
  const r = await fetchWithRetry(url.toString(), {
    headers: { Authorization: `Bearer ${token}` },
  });
  if (!r.ok) {
    const body = await r.text();
    throw new Error(`Fogo Cruzado ${path} ${r.status}: ${body.slice(0, 200)}`);
  }
  return r.json();
}

/**
 * Fetch com retry exponencial pra falhas transientes (network, 5xx).
 * 4xx é considerado erro permanente — retorna na primeira tentativa.
 * Função pura em termos de side-effects observáveis pelo caller:
 * sucesso devolve Response, falha total lança o último erro.
 */
async function fetchWithRetry(url, options = {}) {
  let lastError;
  for (let attempt = 0; attempt < MAX_RETRIES; attempt++) {
    try {
      const r = await fetch(url, options);
      if (r.ok || (r.status >= 400 && r.status < 500)) {
        return r;
      }
      // 5xx — transiente, vai retry
      lastError = new Error(`HTTP ${r.status}`);
    } catch (e) {
      // network error, timeout — transiente
      lastError = e;
    }
    if (attempt < MAX_RETRIES - 1) {
      const backoff = BASE_BACKOFF_MS * Math.pow(2, attempt);
      await new Promise((resolve) => setTimeout(resolve, backoff));
    }
  }
  throw lastError;
}

module.exports = { BASE_URL, getToken, authedFetch, fetchWithRetry };
