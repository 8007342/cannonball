import assert from 'node:assert/strict';
import test from 'node:test';
import worker, { CannonballGlobal, createWorker } from '../src/index.mjs';
import { database } from './helpers.mjs';

const origin = 'https://cannonball.tlatoani.net';
function fixture() {
  const { storage } = database(); const object = new CannonballGlobal({ storage });
  const env = { APP_ORIGIN: origin, GOOGLE_CLIENT_ID: 'public-client', CANNONBALL_STORE: { idFromName: name => name, get: () => object } };
  const app = createWorker({ verify: async (token, audience, nonce) => {
    assert.equal(audience, 'public-client');
    if (token !== nonce) throw new Error('bad test token');
    return 'private-subject';
  } });
  return { env, app, request: (path, options = {}) => app.fetch(new Request(origin + path, options), env) };
}
const post = (body = {}, headers = {}) => ({ method: 'POST', headers: { origin, 'content-type': 'application/json', ...headers }, body: JSON.stringify(body) });
function cookieHeader(response, name) {
  return response.headers.getSetCookie().find(value => value.startsWith(name + '='))?.split(';')[0];
}

test('health does not claim live storage; methods and unknown APIs are JSON', async () => {
  const health = await worker.fetch(new Request(origin + '/api/health'));
  assert.equal(health.headers.get('cache-control'), 'no-store');
  assert.equal((await health.json()).storageConfigured, false);
  assert.equal((await worker.fetch(new Request(origin + '/api/health', post()))).status, 405);
  assert.equal((await worker.fetch(new Request(origin + '/api/missing'))).status, 404);
});

test('mutations reject wrong/missing Origin, sibling site, non-JSON, malformed and oversized bodies', async () => {
  const { request } = fixture();
  for (const headers of [{ origin: 'https://evil.example' }, { origin: 'null' }, { 'sec-fetch-site': 'same-site' }]) {
    assert.equal((await request('/api/auth/google', post({}, headers))).status, 403);
  }
  assert.equal((await request('/api/auth/google', { method: 'POST', body: '{}' })).status, 403);
  assert.equal((await request('/api/auth/google', post({}, { 'content-type': 'text/plain' }))).status, 415);
  assert.equal((await request('/api/auth/google', { ...post(), body: '{' })).status, 400);
  assert.equal((await request('/api/auth/google', post({ credential: 'a'.repeat(33000) }))).status, 413);
  assert.equal((await request('/api/auth/challenge', { headers: { 'sec-fetch-site': 'cross-site' } })).status, 403);
});

test('browser challenge is single-use and cookies are independent, host-only, secure; logout revokes', async () => {
  const { request } = fixture();
  assert.deepEqual(await (await request('/api/session')).json(), { account: null, progress: null });
  const challenge = await request('/api/auth/challenge'); const { nonce } = await challenge.json();
  const bound = cookieHeader(challenge, '__Host-cannonball_challenge');
  assert.ok(bound);
  const response = await request('/api/auth/google', post({ credential: nonce }, { cookie: bound }));
  assert.equal(response.status, 200);
  const result = await response.json(); assert.ok(result.account.id); assert.deepEqual(result.progress.unlocks, ['wagon']);
  for (const value of response.headers.getSetCookie()) {
    assert.match(value, /Secure; HttpOnly; SameSite=Strict/); assert.doesNotMatch(value, /Domain=/);
  }
  const session = cookieHeader(response, '__Host-cannonball_session');
  assert.equal((await request('/api/auth/google', post({ credential: nonce }, { cookie: bound }))).status, 401);
  assert.equal((await (await request('/api/session', { headers: { cookie: session } })).json()).account.id, result.account.id);
  assert.equal((await request('/api/auth/logout', post({}, { cookie: session }))).status, 200);
  assert.equal((await (await request('/api/session', { headers: { cookie: session } })).json()).account, null);
});

test('cloud unavailable is explicit and anonymous ranking mutations cannot create records', async () => {
  const { request, app } = fixture();
  assert.equal((await request('/api/runs/start', post({ carId: 'wagon' }))).status, 401);
  const response = await app.fetch(new Request(origin + '/api/session'), { APP_ORIGIN: origin });
  assert.equal(response.status, 503); assert.equal((await response.json()).error, 'storage_unavailable');
});
