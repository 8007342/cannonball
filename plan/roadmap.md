# Cannonball roadmap

Current phase: the painted S2000 driving-and-camera test course is implemented for review. It adds authored hills/bends, progressive steering and departure continuity. Active work and evidence: openspec/changes/playable-road-trip. Campaign stages, rather than the entire country, now target10–15minutes.

1. Replace the rejected primitive renderer with a measured Baja-inspired cartoon
   proof: textured ground, animated suspension/wheels/poses, cached parallax,
   depth-correct scenery/bridges and a real scene pixel budget. Review a moving
  30–60s sample before production packs; see docs/research/renderer-audit.md.
2. Finalize starter-car story, garage ownership, storyboard/cutscenes and authored
   hints; replace provisional radio/score with the approved production voice and
   instrument library while preserving continuous driving.
3. Use the operator-confirmed Google origin, provision Cloudflare
   Pages/Worker/SQLite and verify live HTTPS login, logout, queued-save recovery,
   cross-device progress and Top100. Shared Arabiya client ID is configured.
4. Real-phone playtesting: tilt permission/calibration, lean direction/amplitude,
   sustained frame times, touch latency and animation readability. Native apps
   remain excluded; URL access is sufficient and PWA installation optional.
5. Tune10–15minute city-to-city campaign stages across cars/routes/seeds with people. One
   deterministic reactive-pilot starter run currently completes in 13:20.700;
   that is simulation evidence, not a human playtest or universal completion claim.

Do not archive the active change or claim production completion while its final
content and live/device acceptance tasks remain unchecked.

The current proof is an illustrative two-minute course. Its moving review does
not approve the nationwide art pack, geographical atlas, physical-device comfort
or live staged saves. Camera presets hold physics constant. Research and review
evidence are under docs/research/course-camera.md and docs/driving-milestone-review.md.


Latest review: low-horizon camera comparisons, depth fades, sparse pictorial
businesses, shorter radio/station surfing and forgiving visible contacts/flying
cones are implemented in the local proof. See docs/camera-radio-contact-review.md.
Gentle-bend cruising assist is now researched/spec'd and tracked separately for
implementation, with no lane-center magnet. All research/provenance documents
are inventoried in docs/research/reference-register.md and linked from the specs.

Current local comparison adopts wide framing, rolling terrain, dense traffic,
damped chase/suspension cues and protected thumb-wide rim controls. Optional
peripheral effects are reviewable separately. Research and local evidence are in
docs/research/rolling-chase-suspension.md; lane-follow assist and physical-phone
acceptance remain open.
