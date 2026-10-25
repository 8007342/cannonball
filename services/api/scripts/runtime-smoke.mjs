// Executes the packaged Worker and real local workerd SQLite Durable Object.
// No live Cloudflare resources or Google requests are used.
import assert from 'node:assert/strict';
import { Miniflare, convertV4MiniflareOptions } from 'miniflare';
import { fileURLToPath } from 'node:url';
const origin = 'https://cannonball.tlatoani.net';
const runtime = new Miniflare(convertV4MiniflareOptions({
  rootPath: fileURLToPath(new URL('../../../', import.meta.url)),
  modules: true, scriptPath: fileURLToPath(new URL('../../../build/worker-check/index.js', import.meta.url)),
  compatibilityDate: '2026-10-25',
  bindings: { APP_ORIGIN: origin, GOOGLE_CLIENT_ID: 'public-test-client' },
  durableObjects: { CANNONBALL_STORE: { className: 'CannonballGlobal', useSQLite: true } },
}));
try {
  const session = await runtime.dispatchFetch(origin + '/api/session');
  assert.equal(session.status, 200); assert.equal((await session.json()).account, null);
  const challenge = await runtime.dispatchFetch(origin + '/api/auth/challenge');
  assert.equal(challenge.status, 200); assert.equal((await challenge.json()).nonce.length, 64);
  const namespace = await runtime.getDurableObjectNamespace('CANNONBALL_STORE');
  const store = namespace.get(namespace.idFromName('cannonball-global-v1'));
  const call = async (operation, args) => {
    const response = await store.fetch('https://internal/', { method: 'POST', body: JSON.stringify({ operation, args }) });
    return { status: response.status, body: await response.json() };
  };
  await call('challenge', { hash: 'fixture-challenge', nonce: 'fixture-nonce' });
  const logins = await Promise.all(Array.from({ length: 2 }, () => call('login', { challengeHash: 'fixture-challenge', nonce: 'fixture-nonce', subject: 'fixture-subject', accountId: crypto.randomUUID(), sessionHash: crypto.randomUUID() })));
  assert.deepEqual(logins.map(result => result.status).sort(), [200, 401]);
  const board = await runtime.dispatchFetch(origin + '/api/hall-of-fame');
  assert.equal(board.status, 200); assert.deepEqual(await board.json(), { entries: [] });
  console.log('Local workerd smoke passed: SQLite schema, challenge/session, concurrent single-use nonce, public board.');
} finally { await runtime.dispose(); }
