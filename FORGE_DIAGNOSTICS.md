# Forge diagnostics

## 2026-10-25 — OpenSpec dates rejected by mirror YAML validation
An earlier work-branch push was rejected by the mirror Ruby/Psych validation
because the generated `.openspec.yaml` used an unquoted date, interpreted as a
Date class by safe_load. Quoting `created: '2026-10-25'` resolved the rejection;
subsequent pushes relayed successfully. Keep scaffold dates quoted. This is a
validation compatibility issue, not an application build failure.

All application checks/builds run locally. No GitHub Actions workflows or remote
build hooks are added or enabled. Main publication here means Git push, not a
verified live Cloudflare deployment. Physical-phone validation remains pending.

## 2026-10-26 — Publisher could not discover the Flutter frontend
The checkout had no root npm package or root Wrangler config; only a nested
Pages config existed. Added root build/deploy commands, pinned Wrangler/lockfile,
Flutter SDK bootstrap for clean Linux hosts, build/web assets and the requested
custom domain. No push-triggered builds/hooks added. Account inspection found
no Cannonball Worker; Pages inspection is unavailable to the connected read-only
credential (missing pages.read). Repository preparation/dry-run is distinct
from a verified live custom-domain deployment.

Verification: npm ci installed the root pinned toolchain; npm run check:deploy
invoked the Flutter release build automatically and Wrangler read118 static
files, then exited without uploading. The local publisher now auto-detects
Wrangler at the root (previously static), serves successfully over HTTPS and
retains live assets. Official SDK manifest lookup for3.47.7/x64 and its checksum
was verified; downloading a fresh SDK was not required on this forge.

Sequence verification:150 Flutter tests,32 browser-script tests,14 API tests,
analyzer, formatting, strict OpenSpec validation and API/asset deployment dry-runs
pass. A Chromium mobile emulation at926×428 CSS pixels/DPR3 loaded the default
six-stage app with291,398 backing pixels and no asset/console error; a rim touch
produced steering.118 and the same applied angle. This is emulation evidence,
not physical iPhone/Safari validation. Full sequence, speed carry, final replay
and stale queued-advance cancellation are covered by widget tests.
