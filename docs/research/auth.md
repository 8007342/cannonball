# Google sign-in and Cloudflare research

Researched 2026-10-25. Recommendations below are design decisions; Cannonball currently has no authentication implementation.

## What Arabiya actually does

Inspected GitHub default-branch tree at commit `7a651d058d3dcc201becf6eb9f5e3150f7f68116`, including [Worker](https://github.com/8007342/arabiya/blob/7a651d058d3dcc201becf6eb9f5e3150f7f68116/worker/index.mjs), [Google button bridge](https://github.com/8007342/arabiya/blob/7a651d058d3dcc201becf6eb9f5e3150f7f68116/web/google-sign-in.js), and [deployment config](https://github.com/8007342/arabiya/blob/7a651d058d3dcc201becf6eb9f5e3150f7f68116/wrangler.jsonc).

Arabiya uses the official Google Identity Services button in popup mode. A same-origin challenge supplies a browser-bound nonce; its JavaScript callback submits the Google ID token to `POST /api/auth/google`. The Worker verifies RS256 signature against Google's keys, issuer, audience, expiry and nonce with `jose`, then creates an opaque expiring host-only Secure/HttpOnly/SameSite cookie. SQLite Durable Object storage holds sessions and progress. Arabiya serves assets and API from one Worker; Cannonball's proposed Pages-plus-API topology keeps the same browser-origin property.

Reuse the interaction and verification design, adapting account storage and save rules. Do not reuse its learning-progress merge schema, default-passcode legacy passport flow, Google identifiers in public ranking data, cookie names, or global storage object name. Review license before copying implementation code. No Arabiya credentials or code were copied into Cannonball.

## Is a new OAuth app required?

A different subdomain alone does not require a different Google Cloud project or OAuth web client. An existing web client can register the additional exact Authorized JavaScript origin `https://cannonball.tlatoani.net`. Its existing registration for Arabiya does not automatically authorize Cannonball. Google documents [client setup and origin registration](https://developers.google.com/identity/gsi/web/guides/get-google-api-clientid).

Recommendation: create a **Cannonball-specific Web application OAuth client**. It can live in the same Google Cloud project if shared branding/audience configuration is appropriate; a separate project is a choice about app branding, isolation and administration. A separate client gives independent origins and token audience configuration. Sharing a Google client does not automatically share the applications' cookies or saves, and Google sign-in is distinct from building a cross-subdomain application session.

For the same GIS popup callback pattern, register the JavaScript origin and no redirect URI is needed. A later redirect-based flow needs its exact callback URL registered; wildcards are not a solution. Origin is scheme + host + optional port, without `/api/...`. Development origins need explicit registration; production-only configuration should not authorize arbitrary preview hosts. [GIS JavaScript reference](https://developers.google.com/identity/gsi/web/reference/js-reference) defines callback and popup/redirect behavior; [Google client management](https://support.google.com/cloud/answer/15549257) defines redirect restrictions.

## Implementation contract for a later auth change

1. Render Google's supported branded button; load GIS after player interaction or when opening account controls. Login never interrupts active driving.
2. Supply a short-lived cryptographically random challenge bound to the browser. Verify allowed Origin and JSON content type on our callback mutations, enforce bounded bodies, consume/rotate nonce to prevent replay, and apply abuse limits. The custom JavaScript callback needs its own documented CSRF defense. If using Google's direct POST integration instead, implement Google's `g_csrf_token` double-submit check rather than assuming the custom callback supplies it.
3. Verify token signature using rotating Google keys and a maintained JOSE implementation, allowed issuer, exact Cannonball client audience, expiration and nonce. Use `sub` as the stable external identity; email is not the account key. Google's [server verification guide](https://developers.google.com/identity/gsi/web/guides/verify-google-id-token) covers validation. Do not accept unsigned decoded claims or a client-supplied account ID.
4. Persist an internal opaque account ID and a mapping from Google subject. Store only needed attributes; do not collect Google name/email/picture merely to put three initials on a leaderboard. Keep public profile and private identity data separate.
5. Issue a host-only `__Host-cannonball_session` Secure/HttpOnly cookie with Path=/ and appropriate SameSite policy, expiry, revocation and logout. Never expose sessions or Google credentials through local storage or Flutter preferences. Do not set Domain=.tlatoani.net.
6. Merge local unlocks only through validated versioned save operations. Competitive cars/unlocks and finished runs need authoritative validation; arbitrary client save uploads cannot award ranked records. Preserve pending saves through retries/account switches and define conflict rules.
7. Real-device acceptance: official popup/FedCM flow, declined/closed popup, stale challenge, reload, second-device sync, expiry, logout, blocked third-party cookies, mobile browsers, and no cross-account progress leakage. Fixture JWT tests cannot prove Google registration or browser popup policy works.

GIS sign-in supplies an ID token for authentication; no client secret is shipped to Flutter or required for this popup identity pattern. Request minimal identity scopes and no Google API access tokens unless a later feature needs them. OAuth authorization-code access to Google APIs would be a separate design.

## Cloudflare ranking authority

Recommend one globally named SQLite Durable Object for each competitive ruleset's ranking decisions, with transactionally persisted run IDs and idempotent submissions. Per-user progress can be partitioned independently. SQLite-backed objects provide [strongly consistent transactional storage](https://developers.cloudflare.com/durable-objects/best-practices/access-durable-objects-storage/). This does not itself stop cheating: client times must be validated against a server-issued run specification and replay or server simulation before admission. Determine fair board partitions for route randomness, car performance, version changes and adaptive difficulty in the design interview.
