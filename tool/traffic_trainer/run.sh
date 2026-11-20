#!/usr/bin/env bash
# Train the racer lane-change classifier on CPU and write the bundle.
#   tool/traffic_trainer/run.sh            # defaults: seed 2026 -> assets/traffic/racer-policy.json
#   tool/traffic_trainer/run.sh --seed 7 --out /tmp/x.json
# Build output stays out of the tmpfs checkout (project cache volume).
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
export CARGO_TARGET_DIR="${CARGO_TARGET_DIR:-$HOME/.cache/tillandsias-project/cannonball-traffic-trainer/target}"
cd "$here"
nice -n 10 cargo run --release -q -- --out "$here/../../assets/traffic/racer-policy.json" "$@"
