# Cannonball API

This Worker implements Google login, account unlocks and one canonical global
Top100 in a SQLite Durable Object named `cannonball-global-v1`. Source implementation,
fixture tests and local workerd validation are complete; live Google origin
registration, Cloudflare provisioning and cross-device browser acceptance are
separate checks. Local guest play does not depend on this service.

## Browser contract

All requests use the page's `/api/...` origin, with browser credentials included.
Mutations require the exact configured `Origin` and `application/json`; bodies are
limited to 32 KiB even without Content-Length. Errors are JSON `{error: code}`.
No endpoint enables cross-origin CORS. Account responses never include Google
name, email, picture or subject. All responses are `Cache-Control: no-store`.

| Request | JSON body | Success response |
| --- | --- | --- |
| GET `/api/health` | — | `{service,status,phase,storageConfigured}`; binding presence is not a live storage probe |
| GET `/api/config` | — | `{googleClientId,origin}` |
| GET `/api/auth/challenge` | — | `{nonce}` and browser-bound challenge cookie |
| POST `/api/auth/google` | `{credential}` | `{account:{id},progress}` and session cookie |
| GET `/api/session` | — | `{account:{id},progress}`, or `{account:null,progress:null}` |
| POST `/api/auth/logout` | `{}` | `{signedOut:true}`; revokes session and clears cookies |
| GET `/api/progress` | — | `{version:1,unlocks:[carId,...]}` |
| PUT `/api/progress` | `{unlocks:[carId,...]}` | Current monotonic progress; unverified new keys rejected |
| POST `/api/runs/start` | `{carId}` | `{runId,seed,rulesetVersion,contentVersion,startedAt}` |
| POST `/api/runs/finish` | `{runId,...receipt}` | `{runId,accepted:true,qualified,progress}` |
| GET `/api/hall-of-fame` | — | `{entries:[entry,...]}` |
| POST `/api/hall-of-fame` | `{runId,initials}` | `{entry,entries}`; initials exactly three A–Z letters |

`entry` contains `rank,runId,initials,carId,elapsedMs,distanceMiles,route`. There is
one board for all cars/routes/conditions. Multiple entries per account are allowed.
Ordering is elapsed time, then server finish acceptance time, then server run ID.
Qualification is checked again transactionally when initials are submitted;
another racer can take the last place while the initials screen is open.
Retrying an identical finish or initials submission does not duplicate a record.
A previously posted entry can fall out of the Top100, in which case an initials
retry returns `entry:null` with the current board.

The client prefetches a signed-in run ticket in the garage and starts with its seed.
A local run without a ready ticket stays local; a late ticket cannot retroactively
rank it. Tickets expire after 24 hours. `startedAt` is Unix milliseconds. A receipt
has `rulesetVersion:'cannonball-1'`, `contentVersion:'us-corridors-1'`, ticket `seed`,
`carId`, integer `elapsedMs`, numeric `distanceMiles`, boolean `completed`,
`route:[{edgeId,fraction}]`, `gates:['mile-155',...]`, integer `crashes` and
`earnedUnlockIds:[carId,...]`. Routes start on Hudson; completed routes end at
Redondo. All but the last edge must be complete. Gate IDs follow cumulative
155-mile milestones. Source `rules.mjs` mirrors the versioned Dart graph/cars.

The server verifies ownership, issued seed, known connected route, distance,
gates and generous upper speed/wall-clock bounds. It derives unlocks from fully
traversed secret edges, and awards the Corvette only on completion with every
other key owned. Failed accepted runs can earn secret keys. Raw guest unlocks
cannot be uploaded to obtain remote cars; a verified account receipt is required.
This is structural and plausibility validation, **not a replay verifier or a
cheat-proof simulation**: a malicious browser can fabricate a plausible receipt.
The authored route miles are approximate corridors, not a surveyed road atlas.

## Google client and sessions

The user chose Arabiya's existing **public web client ID**, recorded in
`wrangler.jsonc`; no client secret or Arabiya session material was copied.
Register the exact JavaScript origin `https://cannonball.tlatoani.net` on that
client. Parent and sibling origins do not authorize it. GIS uses a popup callback,
so this flow needs no redirect URI. Explicitly register any intended development
origin; do not authorize arbitrary preview domains.

Load Google's official GIS button with the config client ID and challenge nonce.
Send the callback ID token only to `/api/auth/google`. JOSE checks Google's
rotating JWKS, RS256 signature, issuer, audience, expiry, issue time and nonce.
The random five-minute challenge is consumed transactionally once. Same-origin
JSON and fetch-metadata checks are this custom callback's CSRF defense; it is not
Google's direct form-POST integration. `__Host-cannonball_session` lasts 30 days,
is Secure/HttpOnly/SameSite=Strict/Path=/, and has no Domain attribute. Session
and challenge bearer tokens are stored only as SHA-256 hashes server-side;
Google `sub` maps privately to a random internal account ID. Login replaces the
current browser session, logout revokes it, and expired records are removed on
store activity. No ID token is stored. API requests have persistent per-IP-hash,
per-endpoint minute limits, with stricter login/challenge and per-account start
limits. Production abuse controls should additionally be monitored at Cloudflare.

## Deployment, storage and recovery

`wrangler.jsonc` declares the `CANNONBALL_STORE` binding and migration `v1` with
`new_sqlite_classes:["CannonballGlobal"]`. Apply through the normal Worker deploy
only after Cloudflare account/zone/Pages routing and Google origin are verified.
The intended topology is Pages assets plus the Worker route
`cannonball.tlatoani.net/api/*`. The API must never fall through to the SPA.
Preview must use isolated configuration/storage, not this production origin or
global object namespace. Never remove or rename the storage binding/object name
to perform a code rollback.

All state transitions use SQLite `transactionSync`; uniqueness constraints guard
subjects, sessions, run IDs and ranking submissions. The single global object is
a deliberate v1 consistency choice; monitor latency and size before partitioning.
Run receipts and posted records remain retained for idempotency/audit. No public
storage administration, export or reset endpoint exists.

Before the first production deployment, record the Worker deployment version,
Durable Object namespace and `idFromName('cannonball-global-v1')` object ID in the
private operations log. Verify access to SQLite Durable Object point-in-time
recovery in the intended Cloudflare account. Before schema changes, record a recovery timestamp or
bookmark and verify a restore against isolated staging data. For an incident:
stop write traffic, capture the affected version/time and preserve evidence,
use Cloudflare's authenticated SQLite recovery tooling to restore the chosen
object checkpoint, deploy the compatible code version, then check sessions,
unlocks, duplicate submissions and Top100 order in staging before reopening.
A code-only rollback redeploys the previous compatible Worker without deleting
its namespace. Recovery may revoke newer sessions and discard post-checkpoint
runs; communicate that explicitly. Recovery access and a real restore drill remain
production acceptance work, not a property established by local tests.

References: [Google server verification](https://developers.google.com/identity/gsi/web/guides/verify-google-id-token),
[Google client setup](https://developers.google.com/identity/gsi/web/guides/get-google-api-clientid),
[Cloudflare SQLite storage and recovery](https://developers.cloudflare.com/durable-objects/api/sqlite-storage-api/).

## Checks

```sh
npm --prefix services/api ci
npm --prefix services/api test
npm --prefix services/api run check
npm --prefix services/api run test:runtime
```

Unit/integration tests exercise the actual SQL store through Node SQLite,
local-key signed JWT verification, nonce replay/expiry, session revocation,
malformed/bounded requests, ownership, unlocks, rejected receipts, ranking order
and idempotency. The runtime smoke packages the Worker and uses local workerd
with a real SQLite Durable Object, including simultaneous consumption of one
nonce. Neither test layer verifies live Google registration/JWKS connectivity,
mobile popup/FedCM behavior, Cloudflare production routing, backup restoration,
or real-device performance. `check` is a **dry-run**, not deployment.
