# Cannonball

A fast paced landscape arcade road trip racer from New York's Red Ball Garage
to The Portofino Hotel & Marina in Redondo Beach, inspired by OutRun's pseudo-3D
racing. Built with Flutter and Flame.

The repository currently contains a runnable foundation screen, web/Android/iOS
scaffolds, OpenSpec requirements, research and Cloudflare deployment preparation.
Driving, finished garage artwork, Google login, saves and rankings are not yet
implemented. Design discovery comes before the gameplay vertical slice.

## Run and check

Toolchain: Flutter **3.47.7**, Dart **3.13.5**, Flame **1.38.2** (resolved in
`pubspec.lock`); Node **22+** for the Worker tooling.

```sh
flutter pub get
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080
flutter analyze
flutter test
flutter build web --release
openspec validate --all --strict
npm --prefix services/api ci
npm --prefix services/api test
npm --prefix services/api run check
```

Gameplay targets landscape. Native orientation preferences and the web manifest
request landscape; unsupported browser locking needs a rotate prompt. Physical
device checks for sensors, browser orientation, audio and performance remain ahead.
Native release signing/builds are not configured or verified here.

## Project memory

- [Requirements](openspec/specs/) — desired behavior, not a completion claim.
- [Design interview](docs/design/interview.md) — choices to settle together.
- [Engine research](docs/research/engine.md) — projection, controls and assets.
- [Flow and route research](docs/research/design.md) — pacing and geography.
- [Identity research](docs/research/auth.md) — Arabiya comparison and Google client.
- [Deployment guide](docs/deployment.md) — Pages, Worker routing and remaining setup.
- [Roadmap](plan/roadmap.md) — remaining milestones and validation gates.
- [Asset contract](assets/README.md) — production pack requirements.

OpenSpec is initialized for Codex with generated skills in `.agents/skills`.
Use an OpenSpec change proposal before expanding implementation. Research
recommendations remain proposals until settled through the interview.

## Intended hosting

Cloudflare Pages serves `https://cannonball.tlatoani.net`; a same-origin Worker
handles `/api/*`. Only the API health endpoint exists. No live deployment,
Cloudflare resource, DNS change or OAuth client was created during initialization.
See the deployment guide before provisioning.
