# Racer traffic and the learned lane-change classifier

Status: implemented on `work/scenic-asset-pipeline` for the reactive traffic
path (`reactiveTraffic: true`, used by the visual proof). Legacy traffic is
unchanged. Tuning values are game choices, not measured traffic data. Real
phones have not been tested yet.

## What Atrapa actually does (and what "JEV" is not)

Neither Cannonball nor [Atrapa](https://github.com/8007342/atrapa) uses the
term "JEV", and no JEV model or engine exists in either repository. When Atrapa
talks about "quick classifiers trained locally", it means this:

- A **pure deterministic rules engine** (`packages/atrapa_rules`) kept separate
  from presentation, with a **bounded local observation encoder**
  (`observation.dart`, a head-centred 9x9 grid plus heading/speed/rays, schema
  `atrapa-grid-v1`) and a **bounded action set** (coast/left/right).
- A **scripted teacher**: a deterministic flood-fill bot (`bot.dart`) with
  seed/tick/actor tie-breaking.
- A **Rust trainer** (`trainer/`, candle, AdamW) that trains a tiny MLP by
  imitating a scripted teacher (behaviour cloning, cross-entropy). It exports
  flat float32 weights, a manifest with a SHA-256, and reference-logit
  fixtures, and checks a plain-Rust reference forward pass for parity. Atrapa
  labels this run *provisional*: it learns a toy grid task, not game rules, and
  the forge ships no trained game weights.
- A **defensive Dart runtime** (`lib/policy/`). The bundle contract
  (`docs/policy-bundle.md`) validates the format, schemas, action order, shapes,
  size, checksum and finiteness. If anything fails, the loader returns a
  fallback result and the game keeps its deterministic baseline bot. The dense
  evaluator takes the argmax over the logits, and the first index wins ties.

Cannonball adapts that approach. It copies none of Atrapa's snake rules, code
or weights.

## Driver mix and speed variety

`RaceController._nextTrafficProfile` uses a deterministic 50-slot cycle,
seeded and spaced by `id * 7`:

| profile  | share | cruise (mph-ish) | headway | notes |
|----------|-------|------------------|---------|-------|
| ordinary | 62 %  | 66–98            | 1.4 s   | |
| cautious | 20 %  | 58–80            | 2.1 s   | brakes for close passes |
| brisk    | 8 %   | 88–115           | 1.4 s   | slows in bends |
| pushy    | 4 %   | 82–108           | 0.9 s   | no signals |
| racer    | 6 %   | 88–97 % of player top speed | 0.6 s | at most 2 alive |

Trucks (18 %, never racers) are capped at 55–75. The racer cruise comes from a
hash, not the traffic RNG, so ordinary traffic keeps its seeded sequence.
Racers always drive sporty models: a placeholder
`traffic_policy/racer_models.dart` cycles `civic_type_r`, `bmw_3_series`,
`mustang` and `tesla_roadster`. The roadster is always white
(`TrafficCar.modelId`). Switch that lookup to `car_catalog.dart` once the
catalog lands.

When the player is slower than a racer's cruise, the racer spawns 260–350
units *behind* the player in a neighbouring lane and passes. A flat-out player
meets racers ahead instead. Racers stay alive for 700 units behind the player
(other cars: 180), so after being passed they can chase. After the player
passes a racer, it boosts for 4.5 s toward max(cruise, player speed). Every
third pass (by id) it tries a 7 s re-pass at up to 99 % of the player's top
speed, so a player at full speed always wins in the end. Racer acceleration is
up to 18 (others 9–10). Racers slow down 12 % at full curve.

## Weaving, safety mask, fallback

Each racer decides every 0.2 s of fixed-step time and picks one of
`keep / left / right / brake / accelerate`
(`traffic_policy/racer_observation.dart`). **The safety mask always applies,
whichever brain decides:**

- Left/right need an adjacent, non-closed lane and no move already under way.
  The gap must clear 30 + 0.9·closing ahead and 22 + 0.9·closing behind. Cars
  already signalling into that lane count as occupants. The player gets
  55/45 + 1.2·closing.
- Accelerate needs 45 + 1.2·closing of room ahead. It is never allowed into a
  closure.
- Keep and brake are always allowed. The follow law (headway 0.6) still brakes
  behind any leader, including the player.

Lane moves are continuous at 1.1 lane-units/s (about 0.6 s per lane). Even-id
racers signal for 0.3 s; odd-id racers do not signal. If the gap closes before
the car is halfway across, it returns to its origin lane. Racers may pass on
either side. Two changes make ordinary drivers better neighbours: their
gap check also respects cars signalling into the target lane, and non-pushy
drivers move over for a racer closing fast from behind when a lane is clear.

Brains, in order: the learned classifier, chosen by masked argmax, if
`RacerPolicyStore.shared` loaded a compatible bundle when `start()` ran.
Otherwise the deterministic `ruleRacerAction`. If evaluation throws, that
decision uses the rule result. `RaceController.racerPolicyId` reports which
brain is active (`rules` or the bundle model id).

## Learned classifier

**Observation (`cannonball-racer-obs-v1`, 24 values):** a one-hot own lane;
speed/160; (cruise − speed)/60. Then, for each of the three lanes: the ahead
gap /300 and relative speed /60, the behind gap /300 and relative speed /60,
and a closed flag. Then player dz /300, dx /1.3 and relative speed /60, and the
curve. All values are clamped to [−1, 1] or [0, 1]. The player also counts as
a lane occupant.

**Trainer (`tool/traffic_trainer`, Rust, single process, std threads):**

1. `sim.rs` is a pure port of the reactive follower law, its lane-change rules
   and closure stops. It adds the racer dynamics and a scripted player who
   holds speed, changes lanes without courtesy and never brakes. The encoder,
   mask and rule fallback are written to be bit-identical with the Dart code.
2. The trainer runs seeded 25 s episodes (7–14 cars, 35 % with a closure,
   recycled around the racer). Each 0.2 s decision is labelled with the best
   *masked* action from a 3 s lookahead rollout (90 steps at 30 Hz) of every
   candidate. Progress is capped at the racer's own cruise. Contacts cost 400,
   player contacts 600, closure entry 400, tailgating 1.5 per unit per step,
   and a lane change 6, which stops dithering. The racer explores with a
   random allowed action 12 % of the time.
3. The model is an MLP 24→32→32→5 (ReLU, 2,021 parameters). It is trained with
   masked softmax cross-entropy, square-root inverse-frequency class weights,
   Adam (lr 0.002, ×0.3 after 2/3) and batch 256. Gradients are summed over 8
   fixed chunks in a fixed order.
4. The bundle is written to `assets/traffic/racer-policy.json` (format
   `cannonball-dense-v1`). It holds base64 float32-LE weights with a SHA-256,
   the schemas, the action order, the training metrics, and 14 parity fixtures
   (raw scene, observation, mask, logits, action and rule action).

The Dart runtime (`traffic_policy/racer_policy.dart`) rejects a bundle with a
wrong format, schema, action order, shape, size (>50k params), base64,
checksum, non-finite weights or a fixture parity failure. It then re-encodes
every fixture scene: observations must match to 1e-12 and logits to 1e-9. Any
encoder drift between Rust and Dart therefore disables the bundle instead of
quietly changing behaviour. Inference accumulates in f64 in a fixed order and
allocates nothing.

### Command and results (seed 2026, this forge, 12 threads)

```sh
tool/traffic_trainer/run.sh              # = cargo run --release -- --out assets/traffic/racer-policy.json
# options: --seed --train-episodes 6000 --eval-episodes 240 --loop-episodes 160
#          --epochs 18 --batch 256 --lr 0.002 --hidden 32 --threads N --out PATH
```

| measure | result |
|---|---|
| wall time | about 20 s total (generate 5.8 s, train 12.4 s); peak RSS 312 MB |
| data | 750k labelled decisions (keep 87.6 %, accelerate 9.4 %, left 1.3 %, right 1.2 %, brake 0.5 %) |
| held-out accuracy (30k decisions from unseen seeds) | **92.7 %** (rule fallback agrees 69.8 %) |
| lane-change recall | 84.8 % |
| weights | 2,021 float32, sha256 `a97cda5b…9d68e3`, model `racer-policy-v1-s2026-a97cda5b8b40` |
| reproducibility | the same weights hash with `--threads 12` and `--threads 3` |
| Rust inference (encode + mask + forward, one thread) | about 0.8–0.94 M decisions/s |
| Dart VM inference (test) | about 0.58–0.74 M decisions/s; the game needs ≤ 10/s (two racers × 5 Hz) |

Closed loop over 160 unseen 25 s episodes (66.7 simulated minutes each):

| driver | mean speed | lane changes/min | NPC contacts/min | racer-caused player contacts/min | closure violations |
|---|---|---|---|---|---|
| lookahead teacher | 122.3 | 5.7 | 0 | 0.27 | 0 s |
| learned + mask | 122.1 | 6.2 | 0 | 0.35 | 0 s |
| rules + mask | 117.8 | 4.0 | 0 | 0.35 | 0 s |

The trainer's player never brakes and swerves without looking, so player
contacts in that sim are a pessimistic upper bound. In the Dart game tests,
racers have no overlaps with the player or NPCs: 24 randomized dense seeds,
plus the scripted weave scenario under both brains. In 18 two-minute proof runs
where the player never steers, 2 of 74 crashes had a racer as the nearest car.

## Determinism and CPU

Everything runs on the controller's fixed 1/60 s step. Decisions use the
pre-step observation and a fixed-step decision clock. The test
`racer traffic is deterministic at 30 and 120 Hz with the policy` compares the
full traffic state, including racer actions and lane-change counts. Each frame
costs O(n²) for n ≤ 22 cars, plus at most two 2k-MAC forward passes every
0.2 s.

## Validation

`test/traffic_racers_test.dart` covers SHA-256, bundle parity, tampered and
missing bundle fallback, mask rules plus a 2,000-scene fuzz, weaving past the
player without overlap (learned and rules), the randomized dense safety sweep,
chasing and re-passing after being passed, closure merging, the speed and
profile distribution, 30/120 Hz determinism, and decision throughput.

Open: tuning on a real device and in real play; rendering of `modelId` sprites
(car catalog); whether racers should signal less or more; the asset
registration in `pubspec.yaml` (`assets/traffic/`). Until it is registered, the
web build silently uses the rule fallback.
