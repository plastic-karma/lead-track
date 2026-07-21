# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

"lead track" (shipped to users as **LeadStone**) is a SwiftUI + SwiftData iOS app with a companion watchOS app. The iOS app is a page-style three-tab shell (Today / Week / Aspirations) for tracking effort: metrics, projects, and timestamped sessions, plus aspirations, intentions, moments, and principles. The watchOS companion lets you start/stop timer metrics and log count metrics from the wrist; it keeps no SwiftData store of its own and syncs with the phone over WatchConnectivity.

## Build & Run

This is an Xcode project (not SPM-based). Build and run via:

```bash
# Build the iOS app
xcodebuild -project "lead track.xcodeproj" -scheme "lead track" -destination 'platform=iOS Simulator,name=iPhone 16' build

# Build the watchOS app (also builds automatically as a dependency of the iOS scheme)
xcodebuild -project "lead track.xcodeproj" -scheme "lead-track Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 10 (46mm)' build
```

No external dependencies — uses only Apple frameworks (SwiftUI, SwiftData, Foundation).

### Building & testing on Linux (SwiftPM overlay)

`Package.swift` at the repo root is an overlay package: it compiles the platform-neutral subset of `Shared/` (models, services, watch-sync logic) plus most of `lead trackTests/` with the open-source Swift toolchain. The Xcode project does not use it — it exists so domain logic can be built and tested without a Mac:

```bash
swift build   # compile the shared subset
swift test    # run the platform-neutral tests (swift-testing)
```

How the subset stays cross-platform:

- `Session`/`Metric`/`Project` wrap `@Model`, `@Relationship`, and `#Unique` in `#if canImport(SwiftData)` (SE-0367), so on Linux they compile as plain classes. Follow this pattern for new model attributes.
- Files that need Apple-only frameworks outright (SwiftUI, ModelContext-coupled services, AppIntents, WidgetKit) are listed in the `exclude:` arrays in `Package.swift`. **A new Apple-only file in `Shared/` or `lead trackTests/` must be added there**, or `swift build` on Linux (and the `linux` CI job) breaks. Whole-file `#if canImport(...)` guards (e.g. `TimerActivityAttributes.swift`) also work and need no exclude entry.
- Targets use Swift language mode v5 to match the Xcode project's `SWIFT_VERSION`.

The local toolchain on this dev box lives at `/workspace/tools/swift` (Swift 6.1.2, matching the `swift:6.1` Linux CI toolchain), exposed via `~/.local/bin/swift{,c}` wrapper scripts that set `LD_LIBRARY_PATH` to `/workspace/tools/sysdeps/lib` for libs the container lacks (ncurses, libxml2, icu).

### Validating the full app from a non-Mac machine

The `xcodebuild` commands above require macOS. The Linux overlay does not fully
exercise the UI and widget surfaces or SwiftData-backed behavior. GitHub Actions
(`.github/workflows/ios.yml`) fills that gap: its macOS job always lints, runs the
macOS overlay tests, and builds the full Xcode project for testing; it runs the
Xcode tests when the runner has a bootable simulator. The Linux job runs
`swift test` for the cross-platform overlay. A green run proves that every app
target compiles and that every test the workflow could execute passed.

For every repository change, use the PR and CI procedure in
[AGENTS.md](AGENTS.md). The workflow also supports `workflow_dispatch` for
one-off validation, but that is not a substitute for the delivery pipeline.

## Feature delivery

For every repository change, follow the mandatory pipeline and scope rules in
[AGENTS.md](AGENTS.md) **without asking for confirmation**. It defines the local
gates, PR and CI requirements, and which app-affecting changes must go through
TestFlight. Run every applicable step and report it.

## Architecture

- **Data layer**: SwiftData with `@Model` classes (see `Shared/Models/`)
- **UI layer**: SwiftUI views with `@Query` for data fetching
- **App entry**: `lead_trackApp.swift` configures the `ModelContainer` and injects it into the SwiftUI environment
- **Targets**: iOS app (`lead track/`), watchOS companion (`lead-track Watch App/`), iOS widget (`lead-track Widget/`), and watchOS widget/complications extension (`lead-track Watch Widget/`) — note the different naming conventions (space vs hyphen). All four compile the `Shared/` folder, so anything there must build on iOS and watchOS — and, unless excluded in `Package.swift`, on Linux too (see "Building & testing on Linux").
- **Watch sync**: the phone is the source of truth. `PhoneWatchSyncService` (iOS) pushes a codable `WatchSnapshot` over WatchConnectivity; the watch (`WatchSyncController`) caches it, renders it, and sends `WatchAction`s back (optimistically applied via `WatchSnapshotReducer`, queued with `transferUserInfo` when the phone is unreachable). The phone applies actions through `WatchActionHandler`, backdating sessions to the action timestamp.

## Linting

Both linters run directly in CI and as Xcode build phases on the iOS app target. To run manually:

```bash
# SwiftLint — style and complexity checks
swiftlint

# SwiftFormat — formatting check (lint only, no changes)
swiftformat --lint .

# SwiftFormat — auto-fix formatting
swiftformat .
```

Both tools ship official Linux binaries, so lint runs locally even on a non-Mac
dev box (use the same versions CI pins in `.github/workflows/ios.yml`): download
`swiftlint_linux_arm64.zip` (use `swiftlint-static`) from realm/SwiftLint and
`swiftformat_linux_aarch64.zip` from nicklockwood/SwiftFormat releases into
`~/.local/bin`. Run both before pushing — CI fails on any SwiftFormat diff.

Complexity thresholds are intentionally strict (see `.swiftlint.yml`): max 5 cyclomatic complexity (warning), 30-line function bodies, 4 parameters. Keep code simple.

## Key Configuration

- Deployment targets: iOS 26.2, watchOS 26.2
- Swift version: 5.0 with modern concurrency features enabled
- Bundle ID: `plastickarma.lead-track`
- Automatic code signing, team ID 9492A97LWY

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
