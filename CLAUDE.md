# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

"lead track" is a SwiftUI + SwiftData iOS app with a companion watchOS app. It uses a NavigationSplitView-based master-detail UI for managing timestamped items. The watchOS app is currently a standalone placeholder.

## Build & Run

This is an Xcode project (not SPM-based). Build and run via:

```bash
# Build the iOS app
xcodebuild -project "lead track.xcodeproj" -scheme "lead track" -destination 'platform=iOS Simulator,name=iPhone 16' build

# Build the watchOS app
xcodebuild -project "lead track.xcodeproj" -scheme "lead track" -destination 'platform=watchOS Simulator,name=Apple Watch Series 10 (46mm)' build
```

No external dependencies — uses only Apple frameworks (SwiftUI, SwiftData, Foundation).

## Architecture

- **Data layer**: SwiftData with `@Model` classes (see `lead track/Item.swift`)
- **UI layer**: SwiftUI views with `@Query` for data fetching
- **App entry**: `lead_trackApp.swift` configures the `ModelContainer` and injects it into the SwiftUI environment
- **Targets**: iOS app (`lead track/`) and watchOS app (`lead-track Watch App/`) — note the different naming conventions (space vs hyphen)

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
