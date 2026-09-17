# lead track

**LeadStone** — a personal effort-tracking app for iOS, built with SwiftUI + SwiftData. Metrics, projects, and sessions record the effort you pour in; aspirations, intentions, moments, and principles hold the why. The iPhone UI is a page-style three-tab shell (Today / Week / Aspirations); a watchOS companion starts timers and logs counts from the wrist, and widget extensions surface metrics on the home screen and watch face.

The app ships under the display name **LeadStone**; "lead track" is the internal project, scheme, and bundle name (`plastickarma.lead-track`) used throughout this repo.

Read saved Moments, intention narrative, check-in notes, and unit-separated effort
through [period retrospectives and opt-in Moment rediscovery](docs/MOMENTS.md#period-retrospectives).
[Set aside an aspiration](docs/ASPIRATIONS.md#set-aside-and-bring-back) without
deleting its history or hiding shared work; bring it back when it matters again.

## Requirements

- Xcode 26 or later
- iOS 26.2 / watchOS 26.2 deployment targets
- Swift 5.0 with modern concurrency

No external dependencies — uses only Apple frameworks (SwiftUI, SwiftData, Foundation).

## Build & Run

```bash
# iOS app
xcodebuild -project "lead track.xcodeproj" -scheme "lead track" \
  -destination 'platform=iOS Simulator,name=iPhone 16' build

# watchOS app
xcodebuild -project "lead track.xcodeproj" -scheme "lead-track Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 10 (46mm)' build
```

You can also open `lead track.xcodeproj` in Xcode and run the desired scheme.

## Project Layout

- `lead track/` — iOS app sources
- `lead-track Watch App/` — watchOS app sources
- `lead-track Widget/` — iOS widget extension
- `lead-track Watch Widget/` — watchOS widget/complications extension
- `Shared/` — models, services, and watch-sync logic compiled into all four targets above
- `lead trackTests/` — unit tests
- `lead trackUITests/` — UI tests
- `Package.swift` — SwiftPM overlay that builds and tests the platform-neutral subset of `Shared/` (plus most unit tests) on Linux: `swift build` / `swift test`; see CLAUDE.md "Building & testing on Linux"
- `docs/` — feature specs and the release guide
- `scripts/` — asset tooling (app-icon generation)

## Linting

Both linters run automatically as Xcode build phases. To run manually:

```bash
swiftlint              # style and complexity checks
swiftformat --lint .   # formatting check
swiftformat .          # auto-fix formatting
```

## Codex Cloud from ChatGPT mobile

Create a Codex Cloud environment for this repository in ChatGPT, select Python
3.12 and Swift 6.1, and use these repository-backed commands:

```sh
# Setup script
./.codex/setup.sh

# Maintenance script
./.codex/maintenance.sh
```

The setup is idempotent and cache-safe. It installs checksum-pinned GitHub CLI
2.101.0, xtool 1.19.2, SwiftLint 0.63.3, and SwiftFormat 0.61.1 binaries for the
cloud runner architecture, resolves Swift packages, and sets a usable Git
identity. Optional `CODEX_GIT_AUTHOR_NAME` and `CODEX_GIT_AUTHOR_EMAIL`
environment variables replace the generic commit identity. The Linux gates are:

```sh
swiftlint
swiftformat --lint .
swift test
```

Use Codex's GitHub connection to create and push a branch or pull request.
Opening or updating a pull request starts both required GitHub Actions jobs
automatically. Enable agent internet access only for required GitHub domains.
Direct `gh workflow run` commands additionally require a `GH_TOKEN` environment
variable available during the agent phase; Codex Cloud secrets are setup-only.
If direct dispatch is necessary, use a dedicated fine-grained token restricted
to this repository with only Contents and Actions access, never a broad personal
token.

The environment installs xtool so Linux compatibility can be evaluated, but it
does not replace the macOS workflow's full Xcode application build, simulator
tests, signing, or TestFlight upload. Configuring xtool for device deployment
would also require an Apple login, an Xcode archive, and a physically connected
iOS device; none of that signing material belongs in Codex setup.

Codex setup runs with internet access and caches the resulting container. The
maintenance script reruns the same idempotent reconciliation after Codex checks
out a task's selected branch.

## License

[MIT](LICENSE)
