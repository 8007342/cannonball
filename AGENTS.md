# Cannonball project guidance

Read README.md and plan/roadmap.md before extending the project. OpenSpec specs
capture desired behavior; they do not imply a feature exists. Check source and
research documents for implementation status. Keep unresolved interview choices
explicit and do not silently turn recommendations into approved design.

Use Flutter + Flame. Keep simulation, road projection, content streaming, input,
audio and persistence separate. Gameplay targets landscape and must stream across
regions without compulsory loading interruptions. Mobile web sensors, orientation
and audio require physical-device validation and fallbacks.

Use OpenSpec change proposals for gameplay features after design discovery.
Before bulk asset generation, approve camera geometry, style guide and a coherent
sample pack. Record asset provenance and metadata. Never copy credentials from
Arabiya or expose Google identity in public rankings.

Checks: dart format --output=none --set-exit-if-changed lib test; flutter analyze;
flutter test; flutter build web --release; openspec validate --all --strict;
npm --prefix services/api test; npm --prefix services/api run check.
Native builds/signing and live Google/Cloudflare configuration require separate
verification. Do not describe dry-runs as live deployment.
