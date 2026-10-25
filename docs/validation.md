# Playable implementation validation — 2026-10-25

## Observed evidence

- Dart formatting and analyzer pass.
- 35 Flutter unit/widget tests pass: deterministic simulation; full-run timing;
  route/gate accounting; reachable closure alternatives; crash recovery; final
  unlock conditions; wheel direction/multitouch; account isolation; durable upload
  retry and recoverable initials; garage/portrait/pause/timeout-recap UI.
- 10 browser-bridge Node tests pass: sensor transforms/calibration/fallback,
  lifecycle, synth/mute/pause, speech failure and official GIS rendering bridge.
- 14 API tests pass: fixture JWT validation, origin/body guards, session/nonce
  replay and expiry, SQL progress/rank transactions, idempotency and engine receipt.
- Wrangler dry-run passes. Local workerd with SQLite passes schema, challenge,
  concurrent single-use nonce, session and board checks. This is actual local
  runtime validation, not live Cloudflare provisioning.
- Release Flutter web build passes, including Wasm compatibility dry-run. The
  default JavaScript build is the preview artifact; Wasm browser behavior has not
  been separately exercised.
- OpenSpec strict validation passes all seven main capabilities plus active change.
- Headless Chromium review: garage and active road render at 1280×720 and an
  emulated 844×390 landscape viewport; start, traffic, route signs and HUD are
  visible. These are visual/layout checks, not physical sensor/audio acceptance.
- Genuine reactive-pilot engine fixture: starter wagon seed731, **13:20.700**,
  2,995 approximate route miles, 19 gates, 12 graph edges, three crashes. Backend
  accepts and ranks the same receipt. No clocks/traffic were edited by the pilot.

## Review build

Managed local static preview: https://www.cannonball.localhost:18443
It serves build/web. The API is not deployed behind this static preview; cloud
unavailability is explicitly shown and guest play remains usable. The API is
separately tested through its local workerd integration suite. The preview is
local to the forge host, not the production cannonball.tlatoani.net deployment.

## Still unverified / incomplete

- Google Console exact-origin registration and actual GIS login on the production
  host. Registering only the parent host is insufficient. The public Arabiya client
  ID is configured; credentials are not fabricated or copied.
- Live Pages/Worker/SQLite provisioning, HTTPS path routing and cross-device saves.
  Connected Cloudflare tools currently expose read-only access and lack pages.read;
  no production deployment is claimed.
- Physical iPhone/Android tilt, permission prompts, audio output, fullscreen,
  camera comfort, thermal/sustained frame time and meaningful human playtests.
- Full surveyed/verified road atlas, exact junction geometry and landmark sightlines.
  Current branches are schematic; flyovers are scenic rather than independently
  navigable multilevel road geometry. Distance is authored corridor approximation.
- Approved final car/biome/region sprite packs, production TTS library/instrument
  bank, full storyboards/cutscenes and final art review. Procedural visuals and
  oscillator score are original first-pass material, not final-content approval.
- Cryptographic/replay authority over the whole simulation. Current result checks
  validate structure and plausibility; a malicious browser can forge plausible data.

The remaining production acceptance tasks remain unchecked in the active change.
