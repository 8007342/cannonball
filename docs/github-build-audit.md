# GitHub build trigger audit — 2026-10-25

The user requires local forge builds and tests only. Frequent remote branch
pushes provide durability and must not trigger GitHub builds.

## Cause

`.github/workflows/release.yml` was added during setup as `Validate Cannonball`,
with `on: [push, pull_request]`. Every work-branch checkpoint could start its
Flutter and Worker jobs. A sampled failed run
[40167149634](https://github.com/8007342/cannonball/actions/runs/40167149634)
was triggered by push; Worker succeeded and Flutter failed at `flutter analyze`.
The emails corresponded to real automatic validation runs on intermediate work.

Local pre-push/post-commit/post-merge hooks delegate branch discipline to
`tillandsias-plan`; the prepare-commit hook adds forge attribution. The observed
remote hooks relay accepted git updates to GitHub. The identified build trigger
was the checked-in Actions workflow. Repository webhook administration was not
available through the connected GitHub reader, and gh had no login; no claim is
made that every externally configured repository webhook was enumerated.

## Correction and verification

Removed all YAML workflows from the tips of main and all eight published work
branches, using normal fast-forward commits and authenticated git pushes. Added
an explicit no-GitHub-Actions/no-remote-build rule to AGENTS.md on every branch.
The commits use skip-ci markers as an additional guard during cleanup. No branch
history was rewritten and no game implementation was merged into main.

Read-only Actions queries reported zero in-progress runs and zero queued runs.
The total remained68after the cleanup pushes, with no new builds created. All
nine remote tips were inspected and contained no `.github/workflows/*.yml` or
`.yaml` files. The repository-wide Actions permission switch was not changed;
removing the workflows prevents these branch pushes from scheduling that CI.

Normal local Flutter, browser-script and Worker checks remain available and are
run in the forge. Future agents must not restore workflows from older commits.
