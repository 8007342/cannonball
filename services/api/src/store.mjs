import { ApiError, CARS, CONTENT_VERSION, RULESET_VERSION, requireCondition, validateReceipt, validateUnlocks } from './rules.mjs';
import { CHALLENGE_MS, SESSION_MS } from './auth.mjs';

export class CannonballStore {
  constructor(storage) {
    this.storage = storage; this.sql = storage.sql;
    this.sql.exec(`CREATE TABLE IF NOT EXISTS accounts (id TEXT PRIMARY KEY, google_sub TEXT NOT NULL UNIQUE, unlocks TEXT NOT NULL);
      CREATE TABLE IF NOT EXISTS sessions (hash TEXT PRIMARY KEY, account_id TEXT NOT NULL, expires_at INTEGER NOT NULL);
      CREATE TABLE IF NOT EXISTS challenges (hash TEXT PRIMARY KEY, nonce TEXT NOT NULL, expires_at INTEGER NOT NULL);
      CREATE TABLE IF NOT EXISTS rates (key TEXT PRIMARY KEY, count INTEGER NOT NULL, expires_at INTEGER NOT NULL);
      CREATE TABLE IF NOT EXISTS runs (id TEXT PRIMARY KEY, account_id TEXT NOT NULL, car_id TEXT NOT NULL, seed INTEGER NOT NULL, started_at INTEGER NOT NULL, receipt TEXT, finished_at INTEGER);
      CREATE TABLE IF NOT EXISTS entries (run_id TEXT PRIMARY KEY, initials TEXT NOT NULL, elapsed_ms INTEGER NOT NULL, accepted_at INTEGER NOT NULL);
      CREATE INDEX IF NOT EXISTS entries_order ON entries(elapsed_ms, accepted_at, run_id);
      CREATE INDEX IF NOT EXISTS sessions_expiry ON sessions(expires_at);
      CREATE INDEX IF NOT EXISTS challenges_expiry ON challenges(expires_at);
      CREATE INDEX IF NOT EXISTS rates_expiry ON rates(expires_at);`);
  }
  rows(query, ...bindings) { return [...this.sql.exec(query, ...bindings)]; }
  one(query, ...bindings) { return this.rows(query, ...bindings)[0]; }
  progress(account) { return { version: 1, unlocks: JSON.parse(account.unlocks) }; }
  account(sessionHash, now, required = true) {
    const row = this.one('SELECT accounts.* FROM accounts JOIN sessions ON sessions.account_id = accounts.id WHERE sessions.hash = ? AND sessions.expires_at > ?', sessionHash || '', now);
    if (!row && required) throw new ApiError(401, 'sign_in_required');
    return row;
  }
  rate(key, limit, now) {
    const row = this.one('SELECT * FROM rates WHERE key = ?', key);
    requireCondition(!row || row.expires_at <= now || row.count < limit, 'rate_limited', 429);
    this.sql.exec('INSERT INTO rates(key,count,expires_at) VALUES (?,1,?) ON CONFLICT(key) DO UPDATE SET count = CASE WHEN expires_at <= ? THEN 1 ELSE count + 1 END, expires_at = CASE WHEN expires_at <= ? THEN ? ELSE expires_at END', key, now + 60000, now, now, now + 60000);
  }
  board() {
    return this.rows('SELECT entries.*, runs.car_id, runs.receipt FROM entries JOIN runs ON runs.id = entries.run_id ORDER BY elapsed_ms, accepted_at, run_id LIMIT 100').map((row, index) => {
      const receipt = JSON.parse(row.receipt);
      return { rank: index + 1, runId: row.run_id, initials: row.initials, carId: row.car_id, elapsedMs: row.elapsed_ms, distanceMiles: receipt.distanceMiles, route: receipt.route };
    });
  }
  qualifies(run, receipt) {
    if (!receipt.completed) return false;
    const ahead = this.one('SELECT COUNT(*) AS total FROM entries WHERE elapsed_ms < ? OR (elapsed_ms = ? AND accepted_at < ?) OR (elapsed_ms = ? AND accepted_at = ? AND run_id < ?)', receipt.elapsedMs, receipt.elapsedMs, run.finished_at, receipt.elapsedMs, run.finished_at, run.id);
    return ahead.total < 100;
  }
  dispatch(operation, args, now = Date.now()) {
    return this.storage.transactionSync(() => {
      this.sql.exec('DELETE FROM sessions WHERE expires_at <= ?', now);
      this.sql.exec('DELETE FROM challenges WHERE expires_at <= ?', now);
      this.sql.exec('DELETE FROM rates WHERE expires_at <= ?', now);
      if (operation === 'limit') { this.rate(args.key, args.limit, now); return {}; }
      if (operation === 'challenge') {
        if (args.previousHash) this.sql.exec('DELETE FROM challenges WHERE hash = ?', args.previousHash);
        this.sql.exec('INSERT INTO challenges VALUES (?,?,?)', args.hash, args.nonce, now + CHALLENGE_MS);
        return { nonce: args.nonce };
      }
      if (operation === 'nonce') {
        const row = this.one('SELECT nonce FROM challenges WHERE hash = ? AND expires_at > ?', args.hash, now);
        requireCondition(row, 'challenge_expired', 401);
        return row;
      }
      if (operation === 'login') {
        const row = this.one('SELECT nonce FROM challenges WHERE hash = ? AND expires_at > ?', args.challengeHash, now);
        requireCondition(row && row.nonce === args.nonce, 'challenge_expired', 401);
        this.sql.exec('DELETE FROM challenges WHERE hash = ?', args.challengeHash);
        let account = this.one('SELECT * FROM accounts WHERE google_sub = ?', args.subject);
        if (!account) {
          this.sql.exec('INSERT INTO accounts VALUES (?,?,?)', args.accountId, args.subject, '["wagon"]');
          account = this.one('SELECT * FROM accounts WHERE id = ?', args.accountId);
        }
        if (args.previousSessionHash) this.sql.exec('DELETE FROM sessions WHERE hash = ?', args.previousSessionHash);
        this.sql.exec('INSERT INTO sessions VALUES (?,?,?)', args.sessionHash, account.id, now + SESSION_MS);
        return { account: { id: account.id }, progress: this.progress(account) };
      }
      if (operation === 'session') {
        const account = this.account(args.sessionHash, now, false);
        return account ? { account: { id: account.id }, progress: this.progress(account) } : { account: null, progress: null };
      }
      if (operation === 'logout') {
        this.sql.exec('DELETE FROM sessions WHERE hash = ?', args.sessionHash || '');
        if (args.challengeHash) this.sql.exec('DELETE FROM challenges WHERE hash = ?', args.challengeHash);
        return { signedOut: true };
      }
      if (operation === 'board') return { entries: this.board() };
      const account = this.account(args.sessionHash, now);
      if (operation === 'progress') return this.progress(account);
      if (operation === 'save') {
        const incoming = validateUnlocks(args.body.unlocks); const known = JSON.parse(account.unlocks);
        requireCondition(incoming.every(id => known.includes(id)), 'unverified_unlock', 409);
        return this.progress(account); // Monotonic: only accepted receipts can add unlocks.
      }
      if (operation === 'start') {
        this.rate(`start:${account.id}`, 20, now);
        requireCondition(Object.hasOwn(CARS, args.body.carId), 'invalid_car');
        requireCondition(JSON.parse(account.unlocks).includes(args.body.carId), 'car_locked', 403);
        const runId = crypto.randomUUID(); const seed = crypto.getRandomValues(new Uint32Array(1))[0] & 0x7fffffff;
        this.sql.exec('INSERT INTO runs(id,account_id,car_id,seed,started_at) VALUES (?,?,?,?,?)', runId, account.id, args.body.carId, seed, now);
        return { runId, seed, rulesetVersion: RULESET_VERSION, contentVersion: CONTENT_VERSION, startedAt: now };
      }
      if (operation === 'finish') {
        requireCondition(typeof args.body.runId === 'string', 'invalid_run');
        let run = this.one('SELECT * FROM runs WHERE id = ? AND account_id = ?', args.body.runId, account.id);
        requireCondition(run, 'run_not_found', 404);
        let receipt;
        if (run.receipt) {
          receipt = JSON.parse(run.receipt);
          // A retry can reproduce acceptance, but cannot replace any recorded score.
          const candidate = validateReceipt(args.body, run, JSON.parse(account.unlocks), run.finished_at).receipt;
          requireCondition(['carId','elapsedMs','distanceMiles','completed','route','seed','gates','crashes'].every(key => JSON.stringify(candidate[key]) === JSON.stringify(receipt[key])), 'run_already_finished', 409);
        } else {
          const accepted = validateReceipt(args.body, run, JSON.parse(account.unlocks), now);
          receipt = accepted.receipt;
          const unlocks = [...new Set([...JSON.parse(account.unlocks), ...accepted.earned])];
          this.sql.exec('UPDATE accounts SET unlocks = ? WHERE id = ?', JSON.stringify(unlocks), account.id);
          this.sql.exec('UPDATE runs SET receipt = ?, finished_at = ? WHERE id = ?', JSON.stringify(receipt), now, run.id);
          run = { ...run, finished_at: now };
        }
        return { runId: run.id, accepted: true, qualified: this.qualifies(run, receipt), progress: this.progress(this.one('SELECT * FROM accounts WHERE id = ?', account.id)) };
      }
      if (operation === 'rank') {
        requireCondition(typeof args.body.runId === 'string' && typeof args.body.initials === 'string' && /^[A-Z]{3}$/.test(args.body.initials), 'invalid_initials');
        const run = this.one('SELECT * FROM runs WHERE id = ? AND account_id = ?', args.body.runId, account.id);
        requireCondition(run && run.receipt, 'finished_run_required', 409);
        const existing = this.one('SELECT initials FROM entries WHERE run_id = ?', run.id);
        if (existing) requireCondition(existing.initials === args.body.initials, 'initials_already_set', 409);
        else {
          const receipt = JSON.parse(run.receipt);
          requireCondition(this.qualifies(run, receipt), 'not_qualified', 409);
          this.sql.exec('INSERT INTO entries VALUES (?,?,?,?)', run.id, args.body.initials, receipt.elapsedMs, run.finished_at);
        }
        const entries = this.board();
        return { entry: entries.find(entry => entry.runId === run.id) ?? null, entries };
      }
      throw new ApiError(404, 'not_found');
    });
  }
}
