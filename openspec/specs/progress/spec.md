# Identity, progression and Hall of Fame

## Purpose
Durable unlocks and a globally consistent arcade scoreboard.

## Requirements

### Requirement: Google identity and remote saves
Signed-in players SHALL persist unlocked cars and approved progress remotely using a verified Google identity. Cookies SHALL remain host-only and HttpOnly; the backend SHALL verify audience, issuer, expiry and nonce and enforce same-origin protections. A dedicated Google web client is proposed, not provisioned.

#### Scenario: returning on another device
- **WHEN** a returning player signs into the same Google account
- **THEN** remotely committed unlocks are restored without erasing newer unlocks

### Requirement: Secret cars
Approved secret backroads SHALL unlock designated cars. Unlock persistence SHALL be idempotent. Guest play and guest-to-account merging remain open design choices.

#### Scenario: repeating a secret
- **WHEN** an already owned secret car is unlocked again
- **THEN** ownership remains consistent without duplicate inventory entries

### Requirement: Global Top 100
One canonical durable Hall of Fame SHALL rank eligible completed runs by shortest total elapsed time. Entries SHALL display exactly three arcade initials, the car used and total time. Ties, multiple entries per player, board seasons and cross-route comparability require decisions. Public names SHALL not expose Google names or emails.

#### Scenario: entering the Top 100
- **WHEN** the server accepts a qualifying finished run
- **THEN** the player is offered three spinning character wheels to choose initials

### Requirement: Ranked integrity
A server SHALL own run identifiers, seeds, rules versions and result acceptance. Client-reported times and unlock claims alone SHALL not be trusted. Ranked verification and abuse controls SHALL be designed before the public leaderboard ships; a browser game cannot promise absolute cheat prevention.

#### Scenario: replaying a submission
- **WHEN** a completed run is submitted twice
- **THEN** at most one result is recorded for that run identifier

### Requirement: Durable concurrency
Progress and ranking updates SHALL use transactional storage with explicit tie ordering, backup and recovery procedures. KV alone SHALL not be the authoritative global ranking store.

#### Scenario: concurrent finishes
- **WHEN** two eligible runs finish concurrently
- **THEN** both are evaluated against a consistent ranking without overwriting one another
