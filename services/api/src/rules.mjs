// Versioned counterpart to lib/game/route.dart and cars.dart. These are authored
// approximate corridors, not a claim of surveyed turn-by-turn road geometry.
export const RULESET_VERSION = 'cannonball-1';
export const CONTENT_VERSION = 'us-corridors-1';
export const CARS = { wagon: 136, coupe: 145, rally: 149, muscle: 157, grandtourer: 163, corvette: 170 };
export const EDGES = Object.fromEntries([
  ['hudson', 'ny', 'poconos', 90], ['keystone', 'poconos', 'youngstown', 330],
  ['allegheny', 'poconos', 'youngstown', 410, 'coupe'],
  ['great-lakes', 'youngstown', 'chicago', 455], ['buckeye', 'youngstown', 'columbus', 180],
  ['heartland', 'columbus', 'st-louis', 420], ['illinois', 'chicago', 'st-louis', 300],
  ['prairie', 'chicago', 'omaha', 470], ['nebraska', 'omaha', 'big-springs', 355],
  ['plains-backroad', 'omaha', 'denver', 560, 'rally'], ['front-range', 'big-springs', 'denver', 195],
  ['rockies', 'denver', 'grand-junction', 245], ['monarch-pass', 'denver', 'grand-junction', 320, 'muscle'],
  ['canyonlands', 'grand-junction', 'salina', 250], ['high-desert', 'salina', 'las-vegas', 290],
  ['ozarks', 'st-louis', 'oklahoma', 500], ['red-earth', 'oklahoma', 'amarillo', 260],
  ['panhandle', 'amarillo', 'albuquerque', 285], ['mesa', 'albuquerque', 'flagstaff', 325],
  ['mojave', 'flagstaff', 'barstow', 355], ['route66', 'flagstaff', 'barstow', 390, 'grandtourer'],
  ['neon-desert', 'las-vegas', 'barstow', 155], ['cajon', 'barstow', 'san-bernardino', 75],
  ['pacific', 'san-bernardino', 'redondo', 85],
].map(([id, from, to, miles, unlock]) => [id, { from, to, miles, unlock }]));

export class ApiError extends Error {
  constructor(status, code) { super(code); this.status = status; }
}
export function requireCondition(condition, code = 'invalid_request', status = 400) {
  if (!condition) throw new ApiError(status, code);
}
export const isObject = (value) => value !== null && typeof value === 'object' && !Array.isArray(value);
export function validateUnlocks(unlocks) {
  requireCondition(Array.isArray(unlocks) && unlocks.length <= 6 && unlocks.every(id => Object.hasOwn(CARS, id)), 'invalid_unlocks');
  return [...new Set(['wagon', ...unlocks])];
}

// Server checks shape, ownership, topology, distance, gates and plausible timing.
// A browser can still fabricate a plausible receipt; this is not replay verification.
export function validateReceipt(receipt, ticket, currentUnlocks, now) {
  requireCondition(isObject(receipt), 'invalid_receipt');
  requireCondition(receipt.rulesetVersion === RULESET_VERSION && receipt.contentVersion === CONTENT_VERSION, 'unsupported_rules');
  requireCondition(receipt.carId === ticket.car_id && receipt.seed === ticket.seed, 'ticket_mismatch');
  requireCondition(typeof receipt.completed === 'boolean', 'invalid_completion');
  requireCondition(Number.isSafeInteger(receipt.elapsedMs) && receipt.elapsedMs >= 0 && receipt.elapsedMs <= 3600000, 'invalid_elapsed');
  requireCondition(receipt.elapsedMs <= now - ticket.started_at + 10000, 'impossible_elapsed');
  requireCondition(now - ticket.started_at <= 86400000, 'run_expired');
  requireCondition(Number.isFinite(receipt.distanceMiles) && receipt.distanceMiles >= 0, 'invalid_distance');
  requireCondition(Number.isSafeInteger(receipt.crashes) && receipt.crashes >= 0 && receipt.crashes <= 10000, 'invalid_crashes');
  requireCondition(Array.isArray(receipt.route) && receipt.route.length >= 1 && receipt.route.length <= 30, 'invalid_route');
  let location = 'ny'; let miles = 0; const earned = new Set(); const visited = new Set();
  for (let i = 0; i < receipt.route.length; i++) {
    const step = receipt.route[i];
    requireCondition(isObject(step) && typeof step.edgeId === 'string' && Object.hasOwn(EDGES, step.edgeId), 'invalid_route');
    const edge = EDGES[step.edgeId];
    requireCondition(!visited.has(step.edgeId) && edge.from === location, 'disconnected_route');
    requireCondition(Number.isFinite(step.fraction) && step.fraction >= 0 && step.fraction <= 1, 'invalid_fraction');
    requireCondition(i === receipt.route.length - 1 || step.fraction === 1, 'unfinished_route_edge');
    visited.add(step.edgeId); miles += edge.miles * step.fraction;
    location = step.fraction === 1 ? edge.to : edge.from;
    if (step.fraction === 1 && edge.unlock) earned.add(edge.unlock);
  }
  requireCondition(Math.abs(miles - receipt.distanceMiles) <= 0.1, 'distance_mismatch');
  requireCondition(!receipt.completed || location === 'redondo', 'incomplete_route');
  requireCondition(receipt.completed || location !== 'redondo', 'completion_mismatch');
  const possibleMiles = CARS[receipt.carId] * 0.52 / 18 * receipt.elapsedMs / 1000;
  requireCondition(miles <= possibleMiles + 0.25, 'impossible_speed');
  const expectedGates = Array.from({ length: Math.floor(miles / 155) }, (_, i) => `mile-${(i + 1) * 155}`);
  requireCondition(Array.isArray(receipt.gates) && JSON.stringify(receipt.gates) === JSON.stringify(expectedGates), 'gate_mismatch');
  const all = new Set([...currentUnlocks, ...earned]);
  if (receipt.completed && ['wagon', 'coupe', 'rally', 'muscle', 'grandtourer'].every(id => all.has(id))) earned.add('corvette');
  const claims = validateUnlocks(receipt.earnedUnlockIds ?? []).filter(id => id !== 'wagon');
  requireCondition(claims.every(id => earned.has(id) || currentUnlocks.includes(id)), 'unverified_unlock');
  return { earned: [...earned], receipt: {
    rulesetVersion: RULESET_VERSION, contentVersion: CONTENT_VERSION, seed: ticket.seed,
    carId: ticket.car_id, elapsedMs: receipt.elapsedMs, distanceMiles: miles,
    completed: receipt.completed, route: receipt.route.map(({ edgeId, fraction }) => ({ edgeId, fraction })),
    gates: expectedGates, crashes: receipt.crashes, earnedUnlockIds: [...earned],
  } };
}
