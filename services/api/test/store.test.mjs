import assert from 'node:assert/strict';
import test from 'node:test';
import { database, login, receipt } from './helpers.mjs';
import { SESSION_MS, CHALLENGE_MS } from '../src/auth.mjs';
import { CannonballStore } from '../src/store.mjs';

const now = 1000000;
function fixture() {
  const fixture = database(); login(fixture.store);
  const ticket = fixture.store.dispatch('start', { sessionHash: 'session', body: { carId: 'wagon' } }, now);
  return { ...fixture, ticket, finish: (body, time = now + 900000) => fixture.store.dispatch('finish', { sessionHash: 'session', body }, time) };
}

test('nonce replay/expiry and session expiry are enforced by durable state', () => {
  const { store } = database(); login(store);
  assert.throws(() => store.dispatch('login', { challengeHash: 'challenge', nonce: 'nonce' }, now), /challenge_expired/);
  store.dispatch('challenge', { hash: 'expired', nonce: 'old' }, now);
  assert.throws(() => store.dispatch('nonce', { hash: 'expired' }, now + CHALLENGE_MS), /challenge_expired/);
  assert.equal(store.dispatch('session', { sessionHash: 'session' }, now + SESSION_MS).account, null);
});

test('validated route earns durable unlock; retries preserve score, ownership and private identity', () => {
  const { store, storage, ticket, finish } = fixture();
  const result = finish(receipt(ticket));
  assert.equal(result.qualified, true); assert.deepEqual(result.progress.unlocks, ['wagon', 'grandtourer']);
  assert.deepEqual(finish(receipt(ticket)), result);
  assert.throws(() => finish(receipt(ticket, { elapsedMs: 900001 })), /run_already_finished/);
  const rank = store.dispatch('rank', { sessionHash: 'session', body: { runId: ticket.runId, initials: 'AAA' } }, now + 900000);
  assert.equal(rank.entry.rank, 1); assert.equal(rank.entry.distanceMiles, 2940);
  assert.equal(store.dispatch('rank', { sessionHash: 'session', body: { runId: ticket.runId, initials: 'AAA' } }, now + 900000).entries.length, 1);
  assert.throws(() => store.dispatch('rank', { sessionHash: 'session', body: { runId: ticket.runId, initials: 'BBB' } }, now + 900000), /initials_already_set/);
  const publicJson = JSON.stringify(rank);
  for (const privateValue of ['google-subject-private', 'account_id', 'google_sub', 'email']) assert.ok(!publicJson.includes(privateValue));
  const restarted = new CannonballStore(storage);
  assert.equal(restarted.dispatch('board', {}, now + 900000).entries.length, 1);
  assert.deepEqual(restarted.dispatch('progress', { sessionHash: 'session' }, now + 900000).unlocks, ['wagon', 'grandtourer']);
  login(store, { subject: 'another-account', sessionHash: 'other', now: now + 900000 });
  assert.throws(() => store.dispatch('rank', { sessionHash: 'other', body: { runId: ticket.runId, initials: 'AAA' } }, now + 900000), /finished_run_required/);
});

test('fabricated route, gates, distance, seed, speed and arbitrary cloud unlocks are rejected atomically', () => {
  const { store, ticket, finish } = fixture();
  for (const override of [
    { seed: ticket.seed + 1 }, { distanceMiles: 1 }, { elapsedMs: 1000 }, { gates: [] },
    { route: [{ edgeId: 'pacific', fraction: 1 }] }, { earnedUnlockIds: ['corvette'] },
    { completed: false }, { route: [{ edgeId: 'hudson', fraction: -1 }] },
  ]) assert.throws(() => finish(receipt(ticket, override)));
  assert.deepEqual(store.dispatch('progress', { sessionHash: 'session' }, now).unlocks, ['wagon']);
  assert.throws(() => store.dispatch('save', { sessionHash: 'session', body: { unlocks: ['corvette'] } }, now), /unverified_unlock/);
  assert.throws(() => store.dispatch('start', { sessionHash: 'session', body: { carId: 'corvette' } }, now), /car_locked/);
  assert.throws(() => finish(receipt(ticket), now + 100), /impossible_elapsed/);
  assert.equal(store.one('SELECT receipt FROM runs WHERE id = ?', ticket.runId).receipt, null);
});

test('failed runs save completed secret edges but cannot rank; partial secret claims fail', () => {
  const { store, ticket, finish } = fixture();
  const body = receipt(ticket, { completed: false, distanceMiles: 500, route: [{ edgeId: 'hudson', fraction: 1 }, { edgeId: 'allegheny', fraction: 1 }], gates: ['mile-155', 'mile-310', 'mile-465'], earnedUnlockIds: ['coupe'], elapsedMs: 300000 });
  assert.throws(() => finish({ ...body, distanceMiles: 295, route: [{ edgeId: 'hudson', fraction: 1 }, { edgeId: 'allegheny', fraction: 0.5 }], gates: ['mile-155'] }), /unverified_unlock/);
  const result = finish(body); assert.equal(result.qualified, false); assert.ok(result.progress.unlocks.includes('coupe'));
  assert.throws(() => store.dispatch('rank', { sessionHash: 'session', body: { runId: ticket.runId, initials: 'AAA' } }, now + 900000), /not_qualified/);
});

test('Corvette needs all prior keys and a completed run; cloud progress never regresses', () => {
  const { store, ticket, finish } = fixture();
  const account = store.account('session', now);
  store.sql.exec('UPDATE accounts SET unlocks = ? WHERE id = ?', JSON.stringify(['wagon','coupe','rally','muscle']), account.id);
  const result = finish(receipt(ticket, { earnedUnlockIds: ['grandtourer', 'corvette'] }));
  assert.deepEqual(result.progress.unlocks, ['wagon','coupe','rally','muscle','grandtourer','corvette']);
  assert.deepEqual(store.dispatch('save', { sessionHash: 'session', body: { unlocks: ['wagon'] } }, now + 900000), result.progress);
});

test('global top 100 orders actual time, then finish acceptance, then run ID; multiple runs per account remain', () => {
  const { store } = fixture(); const account = store.account('session', now);
  // Populate accepted receipt fixtures to exercise the real canonical SQL query.
  for (let i = 0; i < 101; i++) {
    const id = `run-${String(i).padStart(3, '0')}`; const elapsed = 900000 + i;
    store.sql.exec('INSERT INTO runs VALUES (?,?,?,?,?,?,?)', id, account.id, 'wagon', i, now, JSON.stringify({ ...receipt({}), elapsedMs: elapsed }), now + elapsed);
    const args = { sessionHash: 'session', body: { runId: id, initials: 'AAA' } };
    if (i < 100) store.dispatch('rank', args, now + elapsed);
    else assert.throws(() => store.dispatch('rank', args, now + elapsed), /not_qualified/);
  }
  const entries = store.dispatch('board', {}, now + 1000000).entries;
  assert.equal(entries.length, 100); assert.equal(entries[0].runId, 'run-000'); assert.equal(entries[99].runId, 'run-099');
  const fast = { ...receipt({}), elapsedMs: 800000 };
  store.sql.exec('INSERT INTO runs VALUES (?,?,?,?,?,?,?)', 'faster', account.id, 'wagon', 0, now, JSON.stringify(fast), now + 1000000);
  const next = store.dispatch('rank', { sessionHash: 'session', body: { runId: 'faster', initials: 'WIN' } }, now + 1000000);
  assert.equal(next.entry.rank, 1); assert.equal(next.entries.length, 100); assert.equal(next.entries[99].runId, 'run-098');
});

test('rate limits persist across store instances', () => {
  const { store, storage } = database();
  store.dispatch('limit', { key: 'test', limit: 1 }, now);
  assert.throws(() => new CannonballStore(storage).dispatch('limit', { key: 'test', limit: 1 }, now), /rate_limited/);
  assert.doesNotThrow(() => store.dispatch('limit', { key: 'test', limit: 1 }, now + 60000));
});


test('equal times use acceptance time and then run ID, independent of initials submission order', () => {
  const { store } = fixture(); const account = store.account('session', now);
  for (const [id, acceptedAt] of [['z-earlier', now + 800000], ['b-later', now + 900000], ['a-later', now + 900000]]) {
    store.sql.exec('INSERT INTO runs VALUES (?,?,?,?,?,?,?)', id, account.id, 'wagon', 1, now, JSON.stringify(receipt({})), acceptedAt);
  }
  for (const id of ['b-later', 'a-later', 'z-earlier']) store.dispatch('rank', { sessionHash: 'session', body: { runId: id, initials: 'AAA' } }, now + 1000000);
  assert.deepEqual(store.dispatch('board', {}, now + 1000000).entries.map(entry => entry.runId), ['z-earlier', 'a-later', 'b-later']);
});

test('actual Dart simulation completion is accepted and can rank once', async () => {
  const { readFile } = await import('node:fs/promises');
  const engine = JSON.parse(await readFile(new URL('./fixtures/engine-completed.json', import.meta.url), 'utf8'));
  const { store } = fixture(); const account = store.account('session', now);
  // Reconstruct issuance around the fixture's genuine server-seed-shaped run.
  const runId = 'engine-seed-731';
  store.sql.exec('INSERT INTO runs(id,account_id,car_id,seed,started_at) VALUES (?,?,?,?,?)', runId, account.id, engine.carId, engine.seed, now);
  const body = { runId, ...engine }; const acceptedAt = now + engine.elapsedMs + 1000;
  const result = store.dispatch('finish', { sessionHash: 'session', body }, acceptedAt);
  assert.equal(result.accepted, true); assert.equal(result.qualified, true);
  assert.deepEqual(store.dispatch('finish', { sessionHash: 'session', body }, acceptedAt + 1000), result);
  const record = store.dispatch('rank', { sessionHash: 'session', body: { runId, initials: 'SIM' } }, acceptedAt);
  assert.equal(record.entry.elapsedMs, 800700); assert.equal(record.entry.distanceMiles, 2995);
});
