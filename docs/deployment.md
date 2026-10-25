# Cloudflare deployment preparation

Status: the playable Flutter client and Worker identity/save/Top100 implementation
are available in source. Worker tests, a Wrangler package dry-run and local
workerd SQLite checks pass. **No live Cloudflare deployment, DNS configuration,
Google origin registration or cross-device acceptance has been verified.**

## Intended topology

- Cloudflare Pages project `cannonball` serves Flutter's `build/web` at `https://cannonball.tlatoani.net`.
- Worker `cannonball-api` intercepts `cannonball.tlatoani.net/api/*` through the path route in `services/api/wrangler.jsonc`. This keeps browser requests and host-only session cookies on one origin. Pages needs a proxied DNS record in the Cloudflare zone for the route to apply.
- Do not attach a Worker Custom Domain to the same entire hostname: it would compete with Pages. Use the API path route.
- The `CANNONBALL_STORE` binding targets the `CannonballGlobal` class; migration `v1` declares it as SQLite-backed. One named object, `cannonball-global-v1`, holds private identity mappings, hashed sessions, progress, issued runs and canonical ranking records. This is the implemented v1 architecture; it has not yet been provisioned live. SQL transactions and unique run IDs provide consistency and idempotency.

Cloudflare documents [Pages custom domains](https://developers.cloudflare.com/pages/configuration/custom-domains/),
[Worker routes](https://developers.cloudflare.com/workers/configuration/routing/routes/)
and [SQLite Durable Object storage](https://developers.cloudflare.com/durable-objects/api/sqlite-storage-api/).

## Verify locally

From the project root:

```sh
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build web --release
openspec validate --all --strict
npm --prefix services/api ci
npm --prefix services/api test
npm --prefix services/api run check
npm --prefix services/api run test:runtime
```

`check` only bundles the Worker and lists its configured bindings; it does not
deploy. `test:runtime` packages the Worker then exercises actual local workerd
and SQLite Durable Object storage, including concurrent single-use nonce
consumption. Node tests cover cryptographic claim rejection and transactional
save/ranking behavior. These checks cannot establish live Google registration,
production routing, a recovery drill, or real-device browser behavior.

For a local API server use `npm --prefix services/api run dev`. Authentication
requires the client and API on the same explicitly configured origin, HTTPS for
Secure cookies, and a Google-authorized JavaScript origin. Override `APP_ORIGIN`
for an isolated development deployment; do not disable origin verification or
weaken production cookie flags. Flutter's standalone static web server has no
API proxy, so it intentionally falls back to local play when `/api/*` is absent.

## First deployment checklist

1. Authenticate Wrangler to the intended Cloudflare account; verify ownership/access to `tlatoani.net`. Do not commit API tokens or local credentials.
2. Verify the existing shared Google web client authorizes **`https://cannonball.tlatoani.net` exactly**. The public client ID is configured in `services/api/wrangler.jsonc`; no client secret is needed for GIS popup identity. Registering `https://tlatoani.net` or Arabiya alone does not authorize Cannonball. See [auth research](research/auth.md) and the [API operations guide](../services/api/README.md).
3. Create Pages project `cannonball` with its production branch. Build Flutter in CI with the pinned SDK and upload `build/web`; a Cloudflare build environment must explicitly install Flutter if building there.
4. Deploy static output from the root with `services/api/node_modules/.bin/wrangler pages deploy build/web --project-name cannonball --config deploy/pages/wrangler.jsonc`.
5. Add `cannonball.tlatoani.net` as a Pages custom domain and wait for certificate/DNS activation. A manually created CNAME alone does not replace Pages custom-domain activation.
6. Run `npm --prefix services/api run deploy` to publish the Worker, SQLite migration and API path route. This changes the live Cloudflare account. Record the deployment version, namespace and global object ID in the private operations log; verify storage recovery access before accepting important records.
7. Confirm `/` renders the game, `/api/health` and `/api/config` return JSON, unknown `/api/*` returns JSON 404, and HTTPS/asset fetching works. `storageConfigured:true` only means the Worker has its binding; check `/api/hall-of-fame` and authenticated writes to establish functioning storage. Ensure Pages SPA fallback cannot swallow API requests.
8. On actual browsers, use the official Google button, verify successful/declined/closed popup behavior, reload, logout, nonce replay rejection, expired sessions, account switching and second-device unlock restoration. Check that sibling hosts cannot use Cannonball cookies. Confirm a completed issued run appears only once and the public board contains initials/car/time/distance/route, never Google identity.
9. Verify mobile orientation, tilt denial and no-event fallback, gesture-gated audio, background pause and a complete uninterrupted run. Record physical-device evidence separately from desktop smoke tests.

Production and preview must use isolated storage and origins. Preview deployments
must not write production ranking records. The config contains the intended
public Google client ID and real binding/migration declarations; it contains no
account ID, secret or fabricated provisioned resource ID.

## Run persistence behavior

Signed-in garage preparation obtains a server-owned run ID/seed/rules version
and checks car ownership. Runs without a ticket remain local. Finished receipts
are validated for route continuity, known cars, distance, gates, plausible timing
and earned keys. This does not make a browser game cheat-proof: server replay
verification is not implemented. The server stores accepted failed runs for
legitimate secret-road unlocks; only completed runs can qualify for the Top100.
Raw guest unlock uploads cannot award remote cars or ranking records.

The global Top100 uses actual outcomes across unequal cars, distances, traffic
and luck. It orders elapsed time, then finish acceptance time, then run ID;
multiple entries per account remain possible. Initials are three uppercase
letters and may collide. Qualification is checked again at initials submission,
and identical retries are idempotent. Public rows contain no account ID, Google
subject, email, name or token. Qualifying initials entry precedes the route recap.

See the [API schema and recovery runbook](../services/api/README.md) for request
bodies, statuses, cookie lifetime, limits, retention and rollback. Before schema
changes, record a SQLite recovery checkpoint and verify an isolated restore.
Code rollback redeploys a compatible previous Worker while preserving its
namespace, binding and global object name. Actual backup restoration remains a
production acceptance task.

## Toolchain note

`services/api/package-lock.json` pins JOSE, Wrangler and Miniflare. The package
overrides transitive `undici` to 7.30.1; dependency installation currently reports
zero vulnerabilities, and tests, bundling and local workerd pass. Reassess the
override when updating tooling. These test/deployment dependencies do not become
the browser bundle; the Worker includes JOSE for ID-token verification.
