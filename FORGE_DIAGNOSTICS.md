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

## 2026-11-11 — Forge asset pipeline availability

This lane is a Linux container (`aarch64`, kernel `6.19.10-300.fc44`) with a
20 GiB overlay filesystem (about 12 GiB free when inspected). Neither `podman`
nor `docker` is on the lane PATH; host-side container operations must go through
the Forge tools. This confirms the Forge container architecture, not the
operator's MacBookAir model or its GPU capabilities.

The Tillandsias host tool index exposes both `image.generate` (local
stable-diffusion.cpp) and a project-scoped ComfyUI `studio.*` pipeline. The
studio initially reported stopped. `studio.start {}` timed out after five
minutes; a subsequent `studio.status {}` still reported it stopped, so no
ComfyUI workflow could run in this session. The Forge model inventory reported
all pinned image and audio models absent from disk.

An image generation request reached the local image pipeline but returned
`consent_required` before running. Its selected model is SDXS-512-0.9 (I0),
requiring a one-time 1.3 GB download. No model was downloaded and no generated
image was produced. The host tool requires the user's affirmative response to
its exact download prompt before retrying with the supplied one-use token.

The project discovery service returned only Cannonball, and no Demonattack
checkout exists under `/home/forge/src` or `/home/forge` in this lane. Its
workflow cannot be inspected or reused from this container as mounted. Existing
Cannonball assets remain the procedural visuals and composed proof assets
described in `assets/README.md`; this session did not generate or add production
assets or pipeline files. Existing asset policy still requires camera geometry,
style guide and a coherent sample pack to be approved before bulk generation.

No app checks were run because this diagnostics-only update does not change app
code or assets. No remote deploy, GitHub workflow or build hook was started.

## 2026-11-11 — Demonattack pipeline review and approved local retry

The operator supplied `https://github.com/8007342/demon_attack` and approved
model downloads. The repository was reachable and cloned read-only to
`/tmp/demon_attack` at `1c3bef7d69ca06b95b8c06db5e289465473cc0e3` (the current
main HEAD at inspection). It is not mounted as a Forge sibling project, but its
tracked pipeline documentation and implementation were available for review.

Demonattack's useful pattern is a strict staged flow: family request planning,
sequential Forge generation, raw ingestion with seed/model/license/hash
provenance, deterministic matte/crop/palette/alpha processing and QA, a review
gallery, explicit human acceptance, then guarded atlas packing. It also keeps
approved keyframes as the identity source for edits and keeps deterministic
runtime assembly downstream of generated source material. Relevant reference
files are `tools/asset_pipeline/README.md`,
`tools/asset_pipeline/pipeline.py`, `tools/sprite_pipeline.py`,
`art/workflows/`, and `plan/asset-pipeline/README.md` in the supplied repo.

The same project has a ComfyUI ACE-Step music workflow and pipeline, and a
separate comms pipeline: Kokoro TTS lines, deterministic synthesized creature
grunts, radio-band processing/squelch, encoding, verification, and generated
runtime-bank metadata. These are strong patterns for Cannonball's regional
music and intercoms, but their ComfyUI graphs and shooter-specific family specs
are not directly compatible with Cannonball's renderer, style, or audio runtime.

Cannonball already has a local deterministic score workflow in
`tool/audio/compose.py`, prepared stock-voice rendering in
`tool/audio/voices.py`, and short radio excerpts in `tool/audio/surf_clips.py`.
Existing proof artwork and generated radio/music drafts are inventoried in
`assets/README.md` and `assets/audio/SCORE_NOTES.md`. The asset README was
corrected to describe these actual files and to keep review material distinct
from approved production content.

With the user's approval, two serial I0 image-generation attempts were made
through the Forge local `image.generate` tool (512×512, 4 steps). Each MCP call
timed out awaiting the host response after 300 seconds. Neither returned an
output path or image, and no image was added to the repository. A later
`gpu.status` response had `holders: []` and `free_vram_gb: null`; it could not
report usable VRAM. `studio.status` still reports the Cannonball studio stopped;
the earlier `studio.start {}` timed out after 300 seconds, and
`studio.models` reports no ComfyUI instance. The model inventory continues to
show pinned models absent. The image tool may have fetched partial setup data,
but a complete model install or inference is not verified. The independent
Demonattack diagnostics describe a Vulkan 16-bit-storage failure on a different
low-power host; this session did not identify this host's GPU or prove that the
same failure is occurring here.

No ComfyUI image, music, or comms graph could be executed in this lane, and no
new art/audio output or generation code was committed. The next Cannonball
pipeline increment should preserve Demonattack's deterministic downstream
stages and manifest/review gates, while first resolving the Forge image/studio
startup failure. Bulk asset generation remains gated on Cannonball camera,
style and coherent sample-pack approval as specified in `assets/README.md`.
