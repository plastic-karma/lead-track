# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

"lead track" is a SwiftUI + SwiftData iOS app with a companion watchOS app. It uses a NavigationSplitView-based master-detail UI for managing timestamped items. The watchOS companion lets you start/stop timer metrics and log count metrics from the wrist; it keeps no SwiftData store of its own and syncs with the phone over WatchConnectivity.

## Build & Run

This is an Xcode project (not SPM-based). Build and run via:

```bash
# Build the iOS app
xcodebuild -project "lead track.xcodeproj" -scheme "lead track" -destination 'platform=iOS Simulator,name=iPhone 16' build

# Build the watchOS app (also builds automatically as a dependency of the iOS scheme)
xcodebuild -project "lead track.xcodeproj" -scheme "lead-track Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 10 (46mm)' build
```

No external dependencies — uses only Apple frameworks (SwiftUI, SwiftData, Foundation).

### Validating builds from a non-Mac machine

The `xcodebuild` commands above require macOS. From Linux/Windows there is no local build path, so validate via GitHub Actions (`.github/workflows/ios.yml`, runs on `macos-latest`), which lints, builds, and tests. A green run confirms the app compiles.

```bash
# On-demand: trigger CI for the current pushed branch (no PR needed; requires workflow_dispatch)
git push -u origin HEAD
gh workflow run ios.yml --ref "$(git branch --show-current)"
gh run watch --exit-status \
  "$(gh run list --workflow=ios.yml --branch "$(git branch --show-current)" --limit 1 --json databaseId --jq '.[0].databaseId')"

# Or open a PR, which triggers the same workflow automatically:
gh pr create --fill && gh pr checks --watch
```

## Architecture

- **Data layer**: SwiftData with `@Model` classes (see `Shared/Models/`)
- **UI layer**: SwiftUI views with `@Query` for data fetching
- **App entry**: `lead_trackApp.swift` configures the `ModelContainer` and injects it into the SwiftUI environment
- **Targets**: iOS app (`lead track/`), watchOS companion (`lead-track Watch App/`), and widget extension (`lead-track Widget/`) — note the different naming conventions (space vs hyphen). All three compile the `Shared/` folder, so anything there must build on iOS and watchOS.
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

Complexity thresholds are intentionally strict (see `.swiftlint.yml`): max 5 cyclomatic complexity (warning), 30-line function bodies, 4 parameters. Keep code simple.

## Key Configuration

- Deployment targets: iOS 26.2, watchOS 26.2
- Swift version: 5.0 with modern concurrency features enabled
- Bundle ID: `plastickarma.lead-track`
- Automatic code signing, team ID 9492A97LWY
