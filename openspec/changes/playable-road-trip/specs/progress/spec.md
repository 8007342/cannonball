## MODIFIED Requirements

### Requirement: Google identity and remote saves
Signed-in players SHALL persist unlocks remotely using verified Google identity. Cannonball SHALL reuse Arabiya's public Google web client ID with an explicitly authorized Cannonball JavaScript origin. Sessions SHALL remain independent and host-only, HttpOnly and Secure. The server SHALL verify token audience, issuer, expiry and nonce and guard mutations against cross-origin requests.

#### Scenario: returning on another device
- **WHEN** a returning player signs into the same Google account
- **THEN** remotely committed unlocks are restored without erasing newer unlocks

#### Scenario: parent host registered alone
- **WHEN** the Google client authorizes only the parent host and not Cannonball's exact origin
- **THEN** the game reports sign-in failure and keeps local play available rather than claiming registration works

## ADDED Requirements

### Requirement: Guest-first browser lifecycle
Players SHALL be able to start locally without signing in. Global submissions SHALL require a valid account and issued run ticket. Local progress SHALL survive reloads when browser storage is available; storage or network failures SHALL not interrupt driving or masquerade as a remote save.

#### Scenario: API unavailable
- **WHEN** a player starts a local run while the API cannot be reached
- **THEN** driving proceeds and the UI clearly distinguishes local progress from cloud-saved records

### Requirement: Connected staged journey foundation
Campaign progress SHALL retain successful versioned city-to-city stage attempts, with car, time, distance, path and conditions. A composed best journey SHALL connect compatible endpoints and versions; different stages MAY use different cars. Experimental local proof records SHALL remain distinct from accepted cloud rankings. New ranking scope remains undecided.

#### Scenario: incompatible stage minima
- **WHEN** the fastest saved stages do not form a connected route
- **THEN** the composed journey SHALL choose a valid connected alternative or report that the destination is not yet connected
