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

The local toolchain on this dev box lives at `/workspace/tools/swift` (Swift 6.1.2, matching CI's Xcode 16.4), exposed via `~/.local/bin/swift{,c}` wrapper scripts that set `LD_LIBRARY_PATH` to `/workspace/tools/sysdeps/lib` for libs the container lacks (ncurses, libxml2, icu).

### Validating the full app from a non-Mac machine

The `xcodebuild` commands above require macOS, and UI/SwiftData/widget code is outside the SwiftPM overlay. Validate those via GitHub Actions (`.github/workflows/ios.yml`): the `build` job on `macos-latest` lints, builds, and tests the Xcode project, and the `linux` job runs `swift test` for the overlay package. A green run confirms the app compiles.

```bash
# On-demand: trigger CI for the current pushed branch (no PR needed; requires workflow_dispatch)
git push -u origin HEAD
gh workflow run ios.yml --ref "$(git branch --show-current)"
gh run watch --exit-status \
  "$(gh run list --workflow=ios.yml --branch "$(git branch --show-current)" --limit 1 --json databaseId --jq '.[0].databaseId')"

# Or open a PR, which triggers the same workflow automatically:
gh pr create --fill && gh pr checks --watch
```

## Feature delivery

When implementing app features or fixes, follow the mandatory pipeline in
[AGENTS.md](AGENTS.md) **without asking for confirmation**: open a PR (CI runs
automatically), watch CI and fix failures until it is green, then dispatch
`release.yml` with `publish_testflight=true` from the PR branch and watch it
succeed. Don't ask the user whether to do these steps — do them and report.

## Architecture

- **Data layer**: SwiftData with `@Model` classes (see `Shared/Models/`)
- **UI layer**: SwiftUI views with `@Query` for data fetching
- **App entry**: `lead_trackApp.swift` configures the `ModelContainer` and injects it into the SwiftUI environment
- **Targets**: iOS app (`lead track/`), watchOS companion (`lead-track Watch App/`), and widget extension (`lead-track Widget/`) — note the different naming conventions (space vs hyphen). All three compile the `Shared/` folder, so anything there must build on iOS and watchOS — and, unless excluded in `Package.swift`, on Linux too (see "Building & testing on Linux").
- **Watch sync**: the phone is the source of truth. `PhoneWatchSyncService` (iOS) pushes a codable `WatchSnapshot` over WatchConnectivity; the watch (`WatchSyncController`) caches it, renders it, and sends `WatchAction`s back (optimistically applied via `WatchSnapshotReducer`, queued with `transferUserInfo` when the phone is unreachable). The phone applies actions through `WatchActionHandler`, backdating sessions to the action timestamp.

## Linting

Both linters run automatically as Xcode build phases on both targets. To run manually:

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
