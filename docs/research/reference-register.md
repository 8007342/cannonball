# Research and reference register

This is the shared source index linked from every main and active-change spec.
It inventories every Markdown research, design, architecture, validation and asset
provenance document under `docs/` and `assets/`. Follow each document for its exact
external source links, publication context and project interpretation. A source
count is an inventory, not a quality score or a claim that a link is live.

Requirements express desired behavior. Historical reports describe their own
builds; they do not override newer user decisions or establish production/device
acceptance. Original artwork prompts and score sources are project provenance,
not scientific evidence. Prior prototype choices are recorded rather than erased.

**Authorship:** GameFlow (2005) is by Penelope Sweetser and Peta Wyeth. Valve's
AI Director, playtesting and art-direction publications are separate references.
SDT work by Ryan, Rigby and Przybylski supplies a complementary motivation lens.
None specifies Cannonball's camera height, contact margin, assist threshold or
roadside repetition rate. Those remain explicit hypotheses and playtest criteria.

Regenerate with `python3 tool/update_reference_register.py`; use `--check` during
local verification. New research documents must appear here before claiming the
spec reference audit is complete. External citations remain in their original
context, avoiding detached or misleading authority claims.

| Document | Role | External source URLs |
| --- | --- | ---: |
| [Asset production](../../assets/README.md) | Asset provenance | 0 |
| [Cannonball original soundtrack studies — 2026-10-25](../../assets/audio/SCORE_NOTES.md) | Asset provenance | 4 |
| [Driving-and-camera milestone sample prompts](../../assets/milestone/PROMPTS.md) | Asset provenance | 0 |
| [Draft asset prompt set](../../assets/proof/PROMPTS.md) | Asset provenance | 0 |
| [Second proof sample art](../../assets/proof-next/PROMPTS.md) | Asset provenance | 0 |
| [Sparse roadside-business sample](../../assets/roadside-pass/PROMPTS.md) | Asset provenance | 0 |
| [Afterburn speed/traffic draft](../../docs/afterburn-draft.md) | Design / implementation / validation | 0 |
| [Proposed runtime boundaries](../../docs/architecture/runtime.md) | Design / implementation / validation | 0 |
| [Low horizon, brief radio and contact review](../../docs/camera-radio-contact-review.md) | Design / implementation / validation | 0 |
| [Cloudflare deployment preparation](../../docs/deployment.md) | Design / implementation / validation | 5 |
| [Design decision register](../../docs/design/decisions.md) | Design / implementation / validation | 1 |
| [Cannonball design interview](../../docs/design/interview.md) | Design / implementation / validation | 0 |
| [Driving-and-camera milestone review](../../docs/driving-milestone-review.md) | Design / implementation / validation | 0 |
| [Playable engine](../../docs/engine.md) | Design / implementation / validation | 0 |
| [Departure continuity: directed 2.5D sample](../../docs/garage-continuity.md) | Design / implementation / validation | 3 |
| [Garage and radio proof](../../docs/garage-radio-proof.md) | Design / implementation / validation | 0 |
| [GitHub build trigger audit — 2026-10-25](../../docs/github-build-audit.md) | Design / implementation / validation | 1 |
| [Browser controls and sound](../../docs/platform.md) | Design / implementation / validation | 3 |
| [Visual proof asset validation](../../docs/proof-assets-validation.md) | Design / implementation / validation | 0 |
| [Visual proof: browser surface and controls](../../docs/proof-platform.md) | Design / implementation / validation | 2 |
| [Short radio interjections and station surfing](../../docs/radio-surfing-draft.md) | Design / implementation / validation | 2 |
| [Second visual proof renderer](../../docs/renderer-next-proof.md) | Design / implementation / validation | 0 |
| [Atrapa-inspired reactive traffic proof](../../docs/research/atrapa-traffic.md) | Research / source interpretation | 4 |
| [Google sign-in and Cloudflare research](../../docs/research/auth.md) | Research / source interpretation | 8 |
| [Lower-horizon camera and flow pass — 2026-10-25](../../docs/research/camera-flow-next.md) | Research / source interpretation | 3 |
| [Proof collision forgiveness and soft construction props](../../docs/research/collision-forgiveness.md) | Research / source interpretation | 3 |
| [Authored road-feel milestone: evidence and implementation](../../docs/research/course-camera.md) | Research / source interpretation | 5 |
| [Cannonball design research](../../docs/research/design.md) | Research / source interpretation | 15 |
| [Cannonball engine and platform research](../../docs/research/engine.md) | Research / source interpretation | 14 |
| [Gentle-road cruising without a lane-center magnet](../../docs/research/lane-following-assist.md) | Research / source interpretation | 3 |
| [Pixel art, smooth movement, and camera lean](../../docs/research/motion-art.md) | Research / source interpretation | 9 |
| [Perceived speed: third-proof research and review protocol](../../docs/research/perceived-speed-milestone.md) | Research / source interpretation | 7 |
| [Renderer rejection, Baja reference and measured limits](../../docs/research/renderer-audit.md) | Research / source interpretation | 10 |
| [Roadside rhythm, motivation and review](../../docs/research/roadside-flow-review.md) | Research / source interpretation | 3 |
| [Speed and score follow-up — 2026-10-25](../../docs/research/speed-and-score-followup.md) | Research / source interpretation | 3 |
| [Dart JavaScript vs Dart WebAssembly experiment](../../docs/research/wasm-benchmark.md) | Research / source interpretation | 2 |
| [S2000 departure and reactive-traffic proof](../../docs/second-proof-review.md) | Design / implementation / validation | 0 |
| [Local stage-record foundation](../../docs/stage-progress.md) | Design / implementation / validation | 0 |
| [Playable implementation validation — 2026-10-25](../../docs/validation.md) | Design / implementation / validation | 1 |
