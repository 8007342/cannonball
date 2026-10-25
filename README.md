# Cannonball

A fast paced landscape arcade road trip racer from New York's Red Ball Garage
to The Portofino Hotel & Marina in Redondo Beach, inspired by OutRun's pseudo-3D
racing. Built with Flutter and Flame.

The repository currently contains a runnable foundation screen, web scaffold,
OpenSpec requirements, research and Cloudflare deployment preparation.
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

Web only: mobile browsers first, desktop browsers with higher-resolution asset
packs, URL access sufficient and optional PWA installation. Successful runs target
10–15 minutes through present-day, researched US roads and landmarks. Landscape
is requested through the web manifest; unsupported browser locking needs a rotate
prompt. Physical browser checks for sensors, audio and performance remain ahead.
The global Top100 records each run's actual car, route and luck; cars and routes
are intentionally not equalized.

## Project memory

- [Requirements](openspec/specs/) — desired behavior, not a completion claim.
- [Design interview](docs/design/interview.md) — choices to settle together.
- [Engine research](docs/research/engine.md) — projection, controls and assets.
- [Motion and art research](docs/research/motion-art.md) — pixel styling, animation and camera lean.
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
