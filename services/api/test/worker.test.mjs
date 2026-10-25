import assert from 'node:assert/strict';
import test from 'node:test';
import worker from '../src/index.mjs';

test('health is explicit about foundation status and never cached', async () => {
  const response = await worker.fetch(new Request('https://cannonball.tlatoani.net/api/health'));
  assert.equal(response.status, 200);
  assert.equal(response.headers.get('cache-control'), 'no-store');
  assert.deepEqual(await response.json(), {
    service: 'cannonball-api', status: 'ok', phase: 'foundation',
  });
});

test('unsupported methods and unknown APIs cannot fall back to SPA HTML', async () => {
  const response = await worker.fetch(new Request('https://cannonball.tlatoani.net/api/health', { method: 'POST' }));
  assert.equal(response.status, 405);
  assert.equal(response.headers.get('allow'), 'GET');
  const auth = await worker.fetch(new Request('https://cannonball.tlatoani.net/api/auth/google'));
  assert.equal(auth.status, 404);
  assert.equal((await auth.json()).error, 'not_found');
});
