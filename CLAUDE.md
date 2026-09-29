# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

"lead track" (shipped to users as **LeadStone**) is a SwiftUI + SwiftData iOS app with a companion watchOS app. The iOS app is a page-style three-tab shell (Today / Week / Aspirations) for tracking effort: metrics, projects, and timestamped sessions, plus aspirations, intentions, moments, and principles. The watchOS companion lets you start/stop timer metrics and log count metrics from the wrist; it keeps no SwiftData store of its own and syncs with the phone over WatchConnectivity.

## Build & Run

Use the local source-built xtool native release stack. The canonical
`lead track.xcodeproj` defines the application; `xtool-release.yml` imports its
complete iOS/watchOS product graph without running Xcode:

```sh
./scripts/build-release.sh --prepare-only  # Import configuration, without compiling.
./scripts/build-release.sh --unsigned      # Compile and verify all five bundles.
./scripts/build-release.sh --upload        # Distribution build and explicit TestFlight upload.
```

Use `XTOOL` to select the installed native CLI or its local environment launcher.
Setup, external signing, and artifact/Apple checks are in
[docs/RELEASE.md](docs/RELEASE.md). Do not substitute GitHub Actions, remote Xcode
runners, or an older upstream xtool binary.

No external dependencies — uses only Apple frameworks (SwiftUI, SwiftData, Foundation).

### Building & testing on Linux (SwiftPM overlay)

`Package.swift` at the repo root is an overlay package: it compiles the platform-neutral subset of `Shared/` (models, services, watch-sync logic) plus most of `lead trackTests/` with the open-source Swift toolchain. The Xcode project does not use it — it exists so domain logic can be built and tested without a Mac:

```bash
swift build   # compile the shared subset
swift test    # run the platform-neutral tests (swift-testing)
```

How the subset stays cross-platform:

- `Session`/`Metric`/`Project` wrap `@Model`, `@Relationship`, and `#Unique` in `#if canImport(SwiftData)` (SE-0367), so on Linux they compile as plain classes. Follow this pattern for new model attributes.
- Files that need Apple-only frameworks outright (SwiftUI, ModelContext-coupled services, AppIntents, WidgetKit) are listed in the `exclude:` arrays in `Package.swift`. **A new Apple-only file in `Shared/` or `lead trackTests/` must be added there**, or local `swift build` / `swift test` on Linux breaks. Whole-file `#if canImport(...)` guards (e.g. `TimerActivityAttributes.swift`) also work and need no exclude entry.
- Targets use Swift language mode v5 to match the Xcode project's `SWIFT_VERSION`.

Use the locally installed Swift 6.4.0 toolchain selected by `xtool-release.yml`.
Keep any compatibility-library environment or launcher outside the repository;
do not change the global Swift selection just to build this app.

### Full application validation

The Linux overlay does not execute SwiftUI, widgets, or SwiftData-backed behavior.
A local `./scripts/build-release.sh --unsigned` compiles and verifies the complete
application, including the iOS widget, share extension, Watch app, and Watch
widget. Watch device bundles retain both `arm64_32` and `arm64`.

Compilation is not a simulator or device test. Exercise persistence, Watch sync,
widgets, sharing, AppIntents, and capabilities on devices when available, and
report runtime verification gaps. Do not claim that portable tests or Apple
processing prove those behaviors. There is no cloud CI fallback.

## Feature delivery

Follow the local-only pipeline in [AGENTS.md](AGENTS.md): local lint/format/tests,
native application builds, and local TestFlight delivery when in scope. GitHub is
for source hosting and PR review only. Do not dispatch workflows or wait for CI
checks. Preserve the existing TestFlight build for docs/tooling-only changes or
when the user asks not to upload.

## Architecture

- **Data layer**: SwiftData with `@Model` classes (see `Shared/Models/`)
- **UI layer**: SwiftUI views with `@Query` for data fetching
- **App entry**: `lead_trackApp.swift` configures the `ModelContainer` and injects it into the SwiftUI environment
- **Targets**: iOS app (`lead track/`), watchOS companion (`lead-track Watch App/`), iOS widget (`lead-track Widget/`), and watchOS widget/complications extension (`lead-track Watch Widget/`) — note the different naming conventions (space vs hyphen). All four compile the `Shared/` folder, so anything there must build on iOS and watchOS — and, unless excluded in `Package.swift`, on Linux too (see "Building & testing on Linux").
- **Watch sync**: the phone is the source of truth. `PhoneWatchSyncService` (iOS) pushes a codable `WatchSnapshot` over WatchConnectivity; the watch (`WatchSyncController`) caches it, renders it, and sends `WatchAction`s back (optimistically applied via `WatchSnapshotReducer`, queued with `transferUserInfo` when the phone is unreachable). The phone applies actions through `WatchActionHandler`, backdating sessions to the action timestamp.

## Linting

Run both linters locally; native xtool builds skip the Xcode project's validation-only linter phases:

```bash
# SwiftLint — style and complexity checks
swiftlint

# SwiftFormat — formatting check (lint only, no changes)
swiftformat --lint .

# SwiftFormat — auto-fix formatting
swiftformat .
```

Use **SwiftLint 0.63.3** and **SwiftFormat 0.61.1**. Download their official
[SwiftLint](https://github.com/realm/SwiftLint/releases/tag/0.63.3) and
[SwiftFormat](https://github.com/nicklockwood/SwiftFormat/releases/tag/0.61.1)
release binaries for the host architecture, verifying release checksums before
installation. On Linux, use SwiftLint's `swiftlint-static` binary; set
`LINUX_SOURCEKIT_LIB_PATH` to the active toolchain's `usr/lib` if needed.
Keep these versions in sync with the local tools, not a hosted workflow.
Run both before pushing. `.build/` and `.xtool/` are excluded; canonical sources
remain covered.

Complexity thresholds are intentionally strict (see `.swiftlint.yml`): max 5 cyclomatic complexity (warning), 30-line function bodies, 4 parameters. Keep code simple.

## Key Configuration

- Deployment targets: iOS 26.2, watchOS 26.2
- Compiler: Swift 6.4.0; application language mode: Swift 5.0 with modern concurrency
- Bundle ID: `plastickarma.lead-track`
- Signing team: `9492A97LWY`; local releases use an external distribution identity and per-bundle App Store profiles

## Localization policy

The app is deliberately English-only for now: there is no String Catalog and
no `.lproj`/`String(localized:)` plumbing, so per-view i18n findings are
expected and not bugs. Locale-SENSITIVE code is a different matter — device
region breaks English-only apps too — so treat these as defects everywhere:
parsing user numeric input with `Double(text)` instead of a locale-aware
parser (`LocaleDoubleParser`), formatting displayed numbers with
`String(format:)` instead of `.formatted(...)`, hand-built plurals, and
locale-dependent wire formats (CSV timestamps are ISO-8601 for this reason).
If localization is ever adopted, start a String Catalog before the string
count grows further.
