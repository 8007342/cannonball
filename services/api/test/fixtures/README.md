# Engine receipt provenance

`engine-completed.json` was emitted on 2026-10-25 by the actual Dart
`RaceController` via `test/game_test.dart`, test “complete starter trip, route
accounting and gate receipts are coherent”. It uses starter wagon, seed 731 and
the test's reactive steering/braking driver with preferred prairie/nebraska/rockies
edges. The driver does not edit clocks, teleport the car or remove traffic.

Observed result: 800700 ms, 2995 authored corridor miles, 12 edges, 19 gates,
three crashes. This fixture is a reproducible engine/API contract check, not a
human or physical-device playtest, verified real-road distance, or proof against
fabricated browser receipts. Regenerate after intentional rules/content changes
and review the API validator alongside the Dart engine.
