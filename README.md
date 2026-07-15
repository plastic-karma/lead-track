# lead track

**LeadStone** — a personal effort-tracking app for iOS, built with SwiftUI + SwiftData. Metrics, projects, and sessions record the effort you pour in; aspirations, intentions, moments, and principles hold the why. The iPhone UI is a page-style three-tab shell (Today / Week / Aspirations); a watchOS companion starts timers and logs counts from the wrist, and widget extensions surface metrics on the home screen and watch face.

The app ships under the display name **LeadStone**; "lead track" is the internal project, scheme, and bundle name (`plastickarma.lead-track`) used throughout this repo.

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

## License

[MIT](LICENSE)
