# Identity, progression and Hall of Fame

## Purpose
Durable unlocks and a globally consistent arcade scoreboard.

## Requirements

### Requirement: Google identity and remote saves
Signed-in players SHALL persist unlocked cars and approved progress remotely using a verified Google identity. Cookies SHALL remain host-only and HttpOnly; the backend SHALL verify audience, issuer, expiry and nonce and enforce same-origin protections. Cannonball SHALL reuse Arabiya’s Google web client ID; the operator confirms exact Cannonball origin registration. Live sign-in remains unverified. Cannonball and Arabiya are sibling hosts under tlatoani.net, with independent application sessions.

#### Scenario: returning on another device
- **WHEN** a returning player signs into the same Google account
- **THEN** remotely committed unlocks are restored without erasing newer unlocks

### Requirement: Secret cars
Approved secret backroads SHALL unlock designated cars. Unlock persistence SHALL be idempotent. Guest play and guest-to-account merging remain open design choices.

#### Scenario: repeating a secret
- **WHEN** an already owned secret car is unlocked again
- **THEN** ownership remains consistent without duplicate inventory entries

### Requirement: Global Top 100

One canonical durable Hall of Fame SHALL order completed runs by shortest total elapsed time. Records SHALL save three arcade initials, car, total time and distance. The table SHALL display initials, car and time; distance display remains open. Public entries SHALL NOT expose Google names or emails. Tie handling and multiple entries per player remain open.

#### Scenario: entering the Top 100
- **WHEN** the server accepts a qualifying finished run
- **THEN** the player first enters initials with three spinning character wheels, the run is saved with time, distance and car, and the route recap follows

### Requirement: Run record integrity
A server SHALL own run identifiers, seeds, rules versions and result acceptance. Client-reported times and unlock claims alone SHALL not be trusted. Result validation SHALL preserve the actual run conditions, not normalize car or route advantages. Verification depth remains an implementation decision; a browser game cannot promise absolute cheat prevention.

#### Scenario: replaying a submission
- **WHEN** a completed run is submitted twice
- **THEN** at most one result is recorded for that run identifier

### Requirement: Durable concurrency
Progress and ranking updates SHALL use transactional storage with explicit tie ordering, backup and recovery procedures. KV alone SHALL not be the authoritative global ranking store.

#### Scenario: concurrent finishes
- **WHEN** two eligible runs finish concurrently
- **THEN** both are evaluated against a consistent ranking without overwriting one another

### Requirement: End-of-run route recap
After every run ends, the game SHALL show a US map containing the game's possible road graph and an animated progress fill along the actual path taken. Completed distance and progress SHALL derive from the run record. Failed runs SHALL stop at their actual endpoint rather than imply a coast-to-coast finish. Qualifying Top100 runs SHALL enter initials before this recap; other runs SHALL proceed directly to it.

#### Scenario: ending a nonqualifying run
- **WHEN** a run ends without a Top100 result
- **THEN** the recap map fills along its recorded road sequence to the endpoint reached

### Requirement: Browser delivery
The game SHALL launch directly from its URL in mobile and desktop browsers. PWA installation MAY be offered but SHALL NOT be required. No native application release is planned.

#### Scenario: playing without installation
- **WHEN** a player opens the game URL in a supported mobile browser
- **THEN** they can enter the game without installing an application

### Requirement: Unequal arcade runs
The shared Top100 SHALL retain differences in car performance, route distance, traffic, complexity and luck. Better unlocked cars SHALL enable better runs. Conditions SHALL NOT be normalized and no equalized competitive mode is required.

#### Scenario: a better car finishes a favorable route
- **WHEN** a valid completed run qualifies with a faster car or favorable random conditions
- **THEN** its actual total time counts on the shared board without a fairness adjustment

## Research and reference traceability

The [project reference register](../../../docs/research/reference-register.md) indexes all research, design,
validation and asset-provenance documents used by this specification. Follow each
entry for original sources and applicability limits. Historical proof evidence
does not imply current production or physical-device acceptance.
