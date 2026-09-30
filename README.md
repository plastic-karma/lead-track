# lead track

**LeadStone** — a personal effort-tracking app for iOS, built with SwiftUI + SwiftData. Metrics, projects, and sessions record the effort you pour in; aspirations, intentions, moments, and principles hold the why. The iPhone UI is a page-style three-tab shell (Today / Week / Aspirations); a watchOS companion starts timers and logs counts from the wrist, and widget extensions surface metrics on the home screen and watch face.

The app ships under the display name **LeadStone**; "lead track" is the internal project, scheme, and bundle name (`plastickarma.lead-track`) used throughout this repo.

Read saved Moments, intention narrative, check-in notes, and unit-separated effort
through [period retrospectives and opt-in Moment rediscovery](docs/MOMENTS.md#period-retrospectives).
[Set aside an aspiration](docs/ASPIRATIONS.md#set-aside-and-bring-back) without
deleting its history or hiding shared work; bring it back when it matters again.

## Requirements

- Local source-built [xtool native release tools](https://github.com/plastic-karma/xtool/blob/main/Documentation/xtool.docc/NativeReleases.md)
- Darwin SDKs imported from your Xcode archive; builds do not run Xcode
- Swift 6.4.0 compiler, Swift 5 application language mode
- iOS 26.2 / watchOS 26.2 deployment targets

No external dependencies — uses only Apple frameworks (SwiftUI, SwiftData, Foundation).

## Build & Run

Build the complete iOS/watchOS application locally:

```sh
./scripts/build-release.sh --prepare-only  # Import the canonical Xcode project.
./scripts/build-release.sh --unsigned      # Full ad-hoc smoke IPA; no upload.
./scripts/build-release.sh --upload        # Distribution build and TestFlight upload.
```

Set `XTOOL` to the source-built CLI or a local environment launcher if it is not
on `PATH`. The build preserves the iPhone app, iPhone widget, share extension,
Watch app, and Watch widget, including both Watch device architectures.

See [the local release guide](docs/RELEASE.md) for setup, external signing,
artifacts, and Apple processing/tester-access checks. Keep credentials outside
the repository. An unsigned smoke IPA is not TestFlight-installable, and a
successful build does not prove device behavior.

## Project Layout

- `lead track/` — iOS app sources
- `lead-track Watch App/` — watchOS app sources
- `lead-track Widget/` — iOS widget extension
- `lead-track Watch Widget/` — watchOS widget/complications extension
- `lead-track Share Extension/` — iOS share extension
- `Shared/` — models, services, and watch-sync logic used by the phone, Watch app, and widget targets
- `lead trackTests/` — unit tests
- `lead trackUITests/` — UI tests
- `Package.swift` — SwiftPM overlay that builds and tests the platform-neutral subset of `Shared/` (plus most unit tests) on Linux: `swift build` / `swift test`; see CLAUDE.md "Building & testing on Linux"
- `docs/` — feature specs and the release guide
- `scripts/` — local xtool release launcher and app-icon generation
- `xtool-release.yml` — native release configuration; imports `lead track.xcodeproj`

## SwiftUI maintenance conventions

- Give meaningful screen sections and lazy-list rows concrete `View` types with
  narrow inputs. Keep small repeated fragments inline when they have no separate
  update boundary; avoid caches that can go stale when SwiftData relationships
  change.
- Own view-local state privately. UI-facing observable controllers use
  `@MainActor` and `@Observable`; non-UI bookkeeping does not participate in
  observation. Create provider/location readers in lifecycle or explicit action
  handlers, not during parent view construction.
- Identify movable rows by the model or calendar date. Photo presentations
  snapshot distinct occurrences once, so duplicate image bytes still have
  different identities. Fixed weekday/bar slots may retain positional identity.
- Prepare thumbnail availability in lifecycle work and omit malformed photos
  before building the tappable strip. Full-resolution covers cache by exact
  bytes with four-entry and 64 MiB cost budgets, including stored bytes and
  estimated decoded pixels; never retain an unbudgeted history of cover edits.
- Use key-path bindings for direct state projections. Keep guarded/actionful
  closure bindings where deletion, uniqueness, or a transformation requires
  them. Reminder edits resolve a row by its durable ID, not its former index.
- Keep disk writes outside `body`. Export links prepare an immutable `ExportFile`
  with `.task(id:)` and hide the previous link as soon as its contents change;
  failed preparation must never offer a stale artifact.
- Prefer current APIs available at the deployment target and direct
  `.enumerated()` collections with Swift 6.4 rather than eager `Array` copies.
  Preserve privacy/authentication boundaries, countdown/recording semantics,
  and the English-only policy; format user-facing numbers and dates with format
  styles.

These boundaries are not a measured performance result. Native compilation and
portable tests do not exercise SwiftUI state retention, photo paging, extension
completion, or Watch delivery on devices; verify those workflows separately.

## Linting

Use SwiftLint 0.63.3 and SwiftFormat 0.61.1 locally. Native xtool builds skip the validation-only Xcode linter phases, so run these explicitly:

```bash
swiftlint              # style and complexity checks
swiftformat --lint .   # formatting check
swiftformat .          # auto-fix formatting
```

## Local tests and delivery

```sh
swift test
```

The SwiftPM overlay tests portable domain logic on Linux. It does not execute
Apple's SwiftData/SwiftUI runtime or the UI-test target. Pair it with a complete
local xtool build for app changes and device testing where available.

Follow [AGENTS.md](AGENTS.md) and [CLAUDE.md](CLAUDE.md) for local gates and delivery.
GitHub is used only for source hosting and review: there are no Actions workflows,
hosted CI requirements, remote Xcode release jobs, or Codex Cloud bootstrap.
Commits, pushes, and tags do not build or upload the app.

## License

[MIT](LICENSE)
