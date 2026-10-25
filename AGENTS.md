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
Web only: no native Android/iOS application is planned. Mobile URL access is the
primary delivery; PWA installation is optional. Use 10–15 minute successful runs,
present-day real geography, soft-edged pixel styling and continuous transitions.
The Top100 intentionally mixes different cars, routes and random conditions; do
not add equalized competitive modes or partition boards to impose fairness.
Live Google/Cloudflare configuration requires separate verification. Do not
describe dry-runs as live deployment.

Build and test locally in the forge. Do not add or enable GitHub Actions workflows
or remote build hooks. Frequent work-branch pushes are for durability and must
not trigger GitHub builds. This is an explicit user requirement.
