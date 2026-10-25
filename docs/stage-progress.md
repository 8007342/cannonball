# Local stage-record foundation

This is a pure-Dart data foundation for the approved city-to-city campaign
structure. It does not migrate the existing cloud API or claim a live saved
campaign. The existing whole-run server receipts and Top100 remain unchanged;
future ranking rules and server stage validation are separate work.

## API

Construct a trusted catalog of `StageDefinition(id, from, to, paths)`. A path is
an ordered list of route-edge IDs. Every allowed alternative in a definition
must share that stage's city/checkpoint endpoints. `StageProgress` receives that
catalog and explicit content/rules versions.

`record(StageAttempt)` accepts only completed positive-time, positive-finite-
distance receipts with a known matching stage ID, endpoint pair, allowed path,
matching versions and nonempty identity/car labels. Attempts are immutable and
identified by an opaque ID. Duplicate IDs are rejected without replacing a
record, while multiple attempts/cars on the same stage are retained. The local
store is bounded to 10,000 attempts to avoid unbounded corrupted-store ingestion.
It is a personal data container, not an authoritative score validator; ownership,
cheat protection and actual road-mile verification belong at the server boundary.

`bestJourney(from, to)` returns the fastest connected directed list of retained
receipts, or null when the destination cannot be reached from those receipts.
Different cars are allowed on successive stages. A disconnected very fast record
cannot be inserted into a journey. Positive durations and a visited-node set
handle cycles. Receipt-ID ordering resolves otherwise identical search ordering.
Times use JSON-safe integers and unsafe composite sums are excluded.

An already reached known endpoint returns an empty journey when `from == to`.
`completedCities` reports destinations of recorded completed attempts. This is
not a full discovery/unlock policy: a campaign controller still decides which
stage starts a player may attempt and when a city garage becomes available.

## Persistence boundary

`toJson()` emits schema version 1, content/rules versions and individual attempts.
`StageProgress.fromJson(value, catalog: ..., contentVersion: ..., rulesVersion:
...)` uses the caller's current trusted catalog, not definitions supplied by the
save. Unsupported or incompatible documents restore empty progress; corrupt
rows are dropped individually. Do not silently rewrite an old save over itself
before offering migration/recovery if production persistence is added.

The caller owns browser storage, guest/cloud merge and error reporting. No writes
or network calls occur inside this module. Records from older handling/content
versions need an explicit migration/archive decision, not automatic competitive
mixing. UI, city-keybox selection, checkpoint timings and all ranking displays
remain integration tasks.

## Validation

`test/stage_progress_test.dart` covers mixed-car composition, disconnected
records, cyclic catalogs, endpoint/path/version checks, JSON round trips,
malformed data, duplicate IDs and immutable collections. The pure module also
passes local Dart analysis and standalone smoke scenarios; integrated Flutter
test execution is performed centrally because the forge toolchain only mounts
the primary project checkout.
