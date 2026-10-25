# Cloudflare deployment preparation

Status: configuration and a tested health-only Worker are prepared. No Cloudflare resources, DNS records, production deployment, Google client, login, save service or Hall of Fame have been created by this setup.

## Intended topology

- Cloudflare Pages project `cannonball` serves Flutter's `build/web` at `https://cannonball.tlatoani.net`.
- Separate Worker `cannonball-api` intercepts `cannonball.tlatoani.net/api/*` through a zone route. This keeps browser requests and eventual session cookies on one origin. The Pages custom domain must have a proxied DNS record in the Cloudflare zone for the route to apply.
- Do not attach a Worker **Custom Domain** to the same entire hostname: it would compete with Pages. Use the API path route in `services/api/wrangler.jsonc`.
- Eventual SQLite Durable Objects: per-user account/progress objects and one named global Hall of Fame object per competitive ruleset. This is a proposed architecture, not a binding or migration currently deployed. Durable storage, transactional insertion and idempotency are required; an in-memory list or eventually consistent KV is insufficient for ranking authority.

Cloudflare documents [Pages custom domains](https://developers.cloudflare.com/pages/configuration/custom-domains/) and [Worker routes](https://developers.cloudflare.com/workers/configuration/routing/routes/). New Durable Objects should use [SQLite-backed storage](https://developers.cloudflare.com/durable-objects/best-practices/access-durable-objects-storage/).

## Verify locally

From the project root:

```sh
flutter pub get
flutter analyze
flutter test
flutter build web --release
npm --prefix services/api ci
npm --prefix services/api test
npm --prefix services/api run check
```

For a local API server use `npm --prefix services/api run dev`. It does not implement login. The current API only provides `GET /api/health`; all other paths return JSON 404. The Node tests check the fetch handler; Wrangler dry-run checks packaging. Neither establishes production routing or real browser behavior.

## First deployment checklist

1. Authenticate Wrangler to the intended Cloudflare account; verify ownership/access to the `tlatoani.net` zone. Do not commit API tokens or local credential files.
2. Create the Pages project `cannonball`, selecting its production branch. For reproducibility build Flutter in CI with the project's pinned SDK; upload `build/web`. Cloudflare's build environment must explicitly install Flutter if building there.
3. Deploy static output from the root with `services/api/node_modules/.bin/wrangler pages deploy build/web --project-name cannonball --config deploy/pages/wrangler.jsonc`.
4. Add `cannonball.tlatoani.net` as a Pages custom domain in the dashboard and wait for its certificate/DNS to activate. A manually created CNAME alone does not replace Pages custom-domain activation.
5. Run `npm --prefix services/api run deploy` to publish the API and path route. This step changes the live Cloudflare account.
6. Confirm `/` renders the game shell, `/api/health` returns JSON, unknown `/api/*` returns JSON 404, HTTPS works, and mobile landscape/asset fetching works. Confirm the API route also works when Pages SPA fallback is active.
7. Configure Google identity only after implementing and testing auth. Use [auth research](research/auth.md); do not point the UI at an endpoint that does not exist.

The configs deliberately contain no account ID, Google client ID, secrets, database binding or fake resource identifier. Production and preview data must be isolated when storage is introduced; preview deployments should never write production ranking records.

## Competitive persistence acceptance criteria

Before enabling global rankings: authenticated run ticket, versioned ruleset/seed/car selection, deterministic run verification or server authority, bounded replay upload, idempotent finish, monotonic elapsed simulation time, transactional rank insertion, tie rule, Top100 qualification/recheck at initials submission, and sanitized three-letter display names. Three letters are a public display label and may collide; run/account IDs must remain globally unique. Do not expose Google names, email addresses, subject IDs or tokens in rankings. Three-letter names reduce public identification but do not eliminate personal-data obligations for authentication, logs and saves.

Decide how adaptive difficulty and randomized closures compare fairly before implementing an all-time global board. A fixed competitive ruleset or separate boards can preserve comparable times while practice/story runs remain adaptive.

## Toolchain note

`services/api/package-lock.json` pins Wrangler. The package overrides transitive `undici` to 7.30.1 to address the advisories reported for the version currently pulled by Wrangler/Miniflare. The override passed Node tests and Wrangler dry-run, and installation reported zero vulnerabilities. Reassess it when updating Wrangler. It affects local deployment tooling, not the health Worker's runtime code.
