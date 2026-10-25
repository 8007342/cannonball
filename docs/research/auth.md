# Google sign-in and Cloudflare research

Researched 2026-10-25. Recommendations below are design decisions; Cannonball currently has no authentication implementation.

## What Arabiya actually does

Inspected GitHub default-branch tree at commit `7a651d058d3dcc201becf6eb9f5e3150f7f68116`, including [Worker](https://github.com/8007342/arabiya/blob/7a651d058d3dcc201becf6eb9f5e3150f7f68116/worker/index.mjs), [Google button bridge](https://github.com/8007342/arabiya/blob/7a651d058d3dcc201becf6eb9f5e3150f7f68116/web/google-sign-in.js), and [deployment config](https://github.com/8007342/arabiya/blob/7a651d058d3dcc201becf6eb9f5e3150f7f68116/wrangler.jsonc).

Arabiya uses the official Google Identity Services button in popup mode. A same-origin challenge supplies a browser-bound nonce; its JavaScript callback submits the Google ID token to `POST /api/auth/google`. The Worker verifies RS256 signature against Google's keys, issuer, audience, expiry and nonce with `jose`, then creates an opaque expiring host-only Secure/HttpOnly/SameSite cookie. SQLite Durable Object storage holds sessions and progress. Arabiya serves assets and API from one Worker; Cannonball's proposed Pages-plus-API topology keeps the same browser-origin property.

Reuse the interaction and verification design, adapting account storage and save rules. Do not reuse its learning-progress merge schema, default-passcode legacy passport flow, Google identifiers in public ranking data, cookie names, or global storage object name. Review license before copying implementation code. No Arabiya credentials or code were copied into Cannonball.

## Is a new OAuth app required?

Cannonball and Arabiya are sibling hostnames: cannonball.tlatoani.net and arabiya.tlatoani.net. Neither is nested under the other; both are subdomains of tlatoani.net and are distinct browser origins. Cannonball will use its own OAuth Web application client. This is the chosen application setup, not a claim that sibling hosts technically require different clients. Google permits explicit origin registration on a web client; Arabiya's origin does not authorize Cannonball automatically. [Google client setup](https://developers.google.com/identity/gsi/web/guides/get-google-api-clientid).

Confirmed plan: create a **Cannonball-specific Web application OAuth client** (not yet provisioned). It can live in the same Google Cloud project if shared branding/audience configuration is appropriate; a separate project is a choice about app branding, isolation and administration. A separate client gives independent origins and token audience configuration. Sharing a Google client does not automatically share the applications' cookies or saves, and Google sign-in is distinct from building a cross-subdomain application session.

For the same GIS popup callback pattern, register the JavaScript origin and no redirect URI is needed. A later redirect-based flow needs its exact callback URL registered; wildcards are not a solution. Origin is scheme + host + optional port, without `/api/...`. Development origins need explicit registration; production-only configuration should not authorize arbitrary preview hosts. [GIS JavaScript reference](https://developers.google.com/identity/gsi/web/reference/js-reference) defines callback and popup/redirect behavior; [Google client management](https://support.google.com/cloud/answer/15549257) defines redirect restrictions.

## Implementation contract for a later auth change

1. Render Google's supported branded button; load GIS after player interaction or when opening account controls. Login never interrupts active driving.
2. Supply a short-lived cryptographically random challenge bound to the browser. Verify allowed Origin and JSON content type on our callback mutations, enforce bounded bodies, consume/rotate nonce to prevent replay, and apply abuse limits. The custom JavaScript callback needs its own documented CSRF defense. If using Google's direct POST integration instead, implement Google's `g_csrf_token` double-submit check rather than assuming the custom callback supplies it.
3. Verify token signature using rotating Google keys and a maintained JOSE implementation, allowed issuer, exact Cannonball client audience, expiration and nonce. Use `sub` as the stable external identity; email is not the account key. Google's [server verification guide](https://developers.google.com/identity/gsi/web/guides/verify-google-id-token) covers validation. Do not accept unsigned decoded claims or a client-supplied account ID.
4. Persist an internal opaque account ID and a mapping from Google subject. Store only needed attributes; do not collect Google name/email/picture merely to put three initials on a leaderboard. Keep public profile and private identity data separate.
5. Issue a host-only `__Host-cannonball_session` Secure/HttpOnly cookie with Path=/ and appropriate SameSite policy, expiry, revocation and logout. Never expose sessions or Google credentials through local storage or Flutter preferences. Do not set Domain=.tlatoani.net.
6. Merge local unlocks only through validated versioned save operations. Cars/unlocks and finished runs need validation; arbitrary client save uploads cannot award Hall of Fame records. Preserve pending saves through retries/account switches and define conflict rules.
7. Real-device acceptance: official popup/FedCM flow, declined/closed popup, stale challenge, reload, second-device sync, expiry, logout, blocked third-party cookies, mobile browsers, and no cross-account progress leakage. Fixture JWT tests cannot prove Google registration or browser popup policy works.

GIS sign-in supplies an ID token for authentication; no client secret is shipped to Flutter or required for this popup identity pattern. Request minimal identity scopes and no Google API access tokens unless a later feature needs them. OAuth authorization-code access to Google APIs would be a separate design.

## Cloudflare ranking authority

Recommend one globally named SQLite Durable Object for the canonical Top100, with transactionally persisted run IDs and idempotent submissions. Per-user progress can be partitioned independently. SQLite-backed objects provide [strongly consistent transactional storage](https://developers.cloudflare.com/durable-objects/best-practices/access-durable-objects-storage/). This does not itself stop cheating. Validate result submissions; whether replay verification or server simulation is warranted is a later implementation decision, not an equalized-competition requirement. User decision: one shared table deliberately includes different route randomness, car performance and difficulty. Do not add equalized conditions or per-car partitions as a fairness requirement. Store time, distance, car and route trace for actual-run records.
