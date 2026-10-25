import { DatabaseSync } from 'node:sqlite';
import { CannonballStore } from '../src/store.mjs';
export function database() {
  const db = new DatabaseSync(':memory:');
  const storage = {
    sql: { exec(query, ...bindings) {
      if (!bindings.length && query.includes(';')) { db.exec(query); return []; }
      const statement = db.prepare(query);
      return statement.columns().length ? statement.all(...bindings) : (statement.run(...bindings), []);
    } },
    transactionSync(callback) {
      db.exec('BEGIN IMMEDIATE');
      try { const result = callback(); db.exec('COMMIT'); return result; }
      catch (error) { db.exec('ROLLBACK'); throw error; }
    },
  };
  return { db, storage, store: new CannonballStore(storage) };
}
export function login(store, { subject = 'google-subject-private', sessionHash = 'session', now = 1000000 } = {}) {
  store.dispatch('challenge', { hash: 'challenge', nonce: 'nonce' }, now);
  return store.dispatch('login', { challengeHash: 'challenge', nonce: 'nonce', subject, accountId: crypto.randomUUID(), sessionHash }, now);
}
export function receipt(ticket, overrides = {}) {
  const route = ['hudson', 'keystone', 'buckeye', 'heartland', 'ozarks', 'red-earth', 'panhandle', 'mesa', 'route66', 'cajon', 'pacific'].map(edgeId => ({ edgeId, fraction: 1 }));
  const distanceMiles = 2940;
  return { ...ticket, carId: 'wagon', elapsedMs: 900000, distanceMiles, completed: true, route, gates: Array.from({ length: Math.floor(distanceMiles / 155) }, (_, i) => `mile-${155 * (i + 1)}`), crashes: 1, earnedUnlockIds: ['grandtourer'], ...overrides };
}
