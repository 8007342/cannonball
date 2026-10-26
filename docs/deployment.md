# Cloudflare deployment preparation

Status: the playable Flutter client and Worker identity/save/Top100 implementation
are available in source. Worker tests, a Wrangler package dry-run and local
workerd SQLite checks pass. **No live Cloudflare deployment, DNS configuration,
Google origin registration or cross-device acceptance has been verified.**

## Default prototype publisher (root config)

The root now has a package.json, lockfile and wrangler.jsonc so the publisher
can discover the Flutter build and static output. Explicit publication:

```sh
npm ci
npm run build                   # Flutter release → build/web
npm run check:deploy            # build + Wrangler dry-run, no upload
npx wrangler deploy             # explicit live upload + custom-domain binding
```

`npm run deploy` is equivalent to the last command. Wrangler's build.command
runs `npm run build` automatically, so the separate build is optional for deploy.
The root Worker is named `cannonball`; it serves static assets with SPA fallback
and declares `cannonball.tlatoani.net` as a custom domain. No account/token is
committed. Publishing must use an account authorized for tlatoani.net. No
GitHub Actions, Cloudflare Git builds or remote build hooks are enabled.

The build uses installed Flutter, or downloads Flutter3.47.7 on a clean Linux
host from the official release manifest, verifying SHA256 before extraction.
Set FLUTTER_BIN to an installed SDK executable when preferred. Node22+, tar
and the standard Flutter Linux build prerequisites are required.

This is the painted mobile review app: six consecutive two-minute stages.
Accounts, rankings and cloud saves are not part of this default prototype.
Opening the HTTPS URL is sufficient; no app installation is required. Rotate
to landscape, take the keys, and play Hudson→Indiana→Iowa→Ohio→Chicago→Arizona.
Q–Y or the level menu jump between stages;1–8 replay chapters; Backspace restarts.
Backgrounding pauses play; resume explicitly. Test audio after the first gesture,
night readability, touch steering/braking, orientation and sustained temperature/
frame rate on physical phones. A desktop browser check is not phone acceptance.

See Cloudflare's [Wrangler configuration](https://developers.cloudflare.com/workers/wrangler/configuration/)
and [custom domains](https://developers.cloudflare.com/workers/configuration/routing/custom-domains/).

## Legacy API / Pages alternative

The older full-run pipeline is retained for receipt tests. Its API Worker is
configured separately in services/api/wrangler.jsonc with a SQLite Durable
Object and an /api/* route. Do not deploy it as a side effect of a static mobile
review publication. It still needs live Google-origin/storage verification.
The nested deploy/pages/wrangler.jsonc remains an explicit Pages alternative;
do not attach Pages and the root static Worker to the same hostname. The
checklist below describes that alternative topology, not the default publisher.

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
3. For the Pages alternative only, create Pages project `cannonball` for direct upload. Build locally with `npm run build`; do not enable Git builds or deploy hooks.
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
