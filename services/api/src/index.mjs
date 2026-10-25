import { ApiError, isObject, requireCondition } from './rules.mjs';
import { CHALLENGE_COOKIE, CHALLENGE_MS, SESSION_COOKIE, SESSION_MS, cookie, hashToken, randomToken, readCookie, verifyGoogle } from './auth.mjs';
import { CannonballStore } from './store.mjs';

export const json = (body, status = 200, headers = {}) => new Response(JSON.stringify(body), {
  status, headers: { 'content-type': 'application/json; charset=utf-8', 'cache-control': 'no-store', 'x-content-type-options': 'nosniff', ...headers },
});
const routes = {
  '/api/health': ['GET'], '/api/config': ['GET'], '/api/session': ['GET'],
  '/api/auth/challenge': ['GET'], '/api/auth/google': ['POST'], '/api/auth/logout': ['POST'],
  '/api/progress': ['GET', 'PUT'], '/api/runs/start': ['POST'], '/api/runs/finish': ['POST'],
  '/api/hall-of-fame': ['GET', 'POST'],
};
export async function readJson(request) {
  requireCondition(request.headers.get('content-type')?.split(';')[0].trim().toLowerCase() === 'application/json', 'json_required', 415);
  requireCondition(!request.headers.has('content-encoding'), 'encoded_body_not_supported', 415);
  requireCondition(Number(request.headers.get('content-length') ?? 0) <= 32768, 'body_too_large', 413);
  const reader = request.body?.getReader(); const chunks = []; let length = 0;
  if (reader) {
    while (true) {
      const { done, value } = await reader.read(); if (done) break;
      length += value.length;
      if (length > 32768) { await reader.cancel(); throw new ApiError(413, 'body_too_large'); }
      chunks.push(value);
    }
  }
  const bytes = new Uint8Array(length); let offset = 0;
  for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.length; }
  let body;
  try { body = JSON.parse(new TextDecoder('utf-8', { fatal: true }).decode(bytes)); }
  catch { throw new ApiError(400, 'invalid_json'); }
  requireCondition(isObject(body), 'invalid_json'); return body;
}

export function createWorker({ verify = verifyGoogle } = {}) {
  return {
    async fetch(request, env = {}) {
      try {
        const url = new URL(request.url); const path = url.pathname; const methods = routes[path];
        if (!methods) return json({ error: 'not_found' }, 404);
        if (!methods.includes(request.method)) return json({ error: 'method_not_allowed' }, 405, { allow: methods.join(', ') });
        if (path === '/api/health') return json({ service: 'cannonball-api', status: 'ok', phase: 'playable', storageConfigured: Boolean(env.CANNONBALL_STORE) });
        const origin = env.APP_ORIGIN;
        requireCondition(typeof origin === 'string' && url.origin === origin, 'origin_not_configured', 503);
        const source = request.headers.get('origin'); const site = request.headers.get('sec-fetch-site');
        const mutation = request.method !== 'GET';
        requireCondition((!mutation && !source || source === origin) && (!site || site === 'same-origin' || site === 'none'), 'origin_forbidden', 403);
        if (path === '/api/config') return json({ googleClientId: env.GOOGLE_CLIENT_ID || null, origin });
        requireCondition(env.CANNONBALL_STORE, 'storage_unavailable', 503);
        const stub = env.CANNONBALL_STORE.get(env.CANNONBALL_STORE.idFromName('cannonball-global-v1'));
        const call = async (operation, args = {}) => {
          const response = await stub.fetch(new Request('https://cannonball-store.internal/', { method: 'POST', body: JSON.stringify({ operation, args }) }));
          const result = await response.json();
          if (!response.ok) throw new ApiError(response.status, result.error || 'storage_unavailable');
          return result;
        };
        const body = mutation ? await readJson(request) : null;
        const ip = request.headers.get('cf-connecting-ip') || 'local';
        await call('limit', { key: `${path}:${await hashToken(ip)}`, limit: path === '/api/auth/google' ? 15 : path === '/api/auth/challenge' ? 30 : 120 });
        const sessionHash = await hashToken(readCookie(request, SESSION_COOKIE));
        const challengeHash = await hashToken(readCookie(request, CHALLENGE_COOKIE));
        if (path === '/api/auth/challenge') {
          requireCondition(env.GOOGLE_CLIENT_ID, 'google_not_configured', 503);
          const token = randomToken(); const nonce = randomToken();
          const result = await call('challenge', { hash: await hashToken(token), nonce, previousHash: challengeHash });
          return json(result, 200, { 'set-cookie': cookie(CHALLENGE_COOKIE, token, CHALLENGE_MS / 1000) });
        }
        if (path === '/api/auth/google') {
          requireCondition(env.GOOGLE_CLIENT_ID, 'google_not_configured', 503);
          const { nonce } = await call('nonce', { hash: challengeHash });
          const subject = await verify(body.credential, env.GOOGLE_CLIENT_ID, nonce);
          const token = randomToken();
          const result = await call('login', { challengeHash, nonce, subject, accountId: crypto.randomUUID(), sessionHash: await hashToken(token), previousSessionHash: sessionHash });
          const response = json(result);
          response.headers.append('set-cookie', cookie(SESSION_COOKIE, token, SESSION_MS / 1000));
          response.headers.append('set-cookie', cookie(CHALLENGE_COOKIE, '', 0));
          return response;
        }
        if (path === '/api/auth/logout') {
          const result = await call('logout', { sessionHash, challengeHash }); const response = json(result);
          response.headers.append('set-cookie', cookie(SESSION_COOKIE, '', 0));
          response.headers.append('set-cookie', cookie(CHALLENGE_COOKIE, '', 0)); return response;
        }
        const operation = path === '/api/session' ? 'session'
          : path === '/api/progress' ? (mutation ? 'save' : 'progress')
          : path === '/api/runs/start' ? 'start' : path === '/api/runs/finish' ? 'finish'
          : mutation ? 'rank' : 'board';
        return json(await call(operation, { sessionHash, body }));
      } catch (error) {
        if (error instanceof ApiError) return json({ error: error.message }, error.status, error.status === 429 ? { 'retry-after': '60' } : {});
        // Never serialize exception/token/identity details to clients or logs.
        return json({ error: 'service_unavailable' }, 503);
      }
    },
  };
}
export default createWorker();

// The only entry is the private Durable Object binding; no public management API.
export class CannonballGlobal {
  constructor(ctx) { this.store = new CannonballStore(ctx.storage); }
  async fetch(request) {
    try {
      const { operation, args } = await request.json();
      return json(this.store.dispatch(operation, args));
    } catch (error) {
      return json({ error: error instanceof ApiError ? error.message : 'storage_unavailable' }, error instanceof ApiError ? error.status : 503);
    }
  }
}
