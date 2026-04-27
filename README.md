# lead track

A SwiftUI + SwiftData iOS app with a companion watchOS app for managing timestamped items, built around a NavigationSplitView master-detail UI.

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
xcodebuild -project "lead track.xcodeproj" -scheme "lead track" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 10 (46mm)' build
```

You can also open `lead track.xcodeproj` in Xcode and run the desired scheme.

## Project Layout

- `lead track/` — iOS app sources
- `lead-track Watch App/` — watchOS app sources
- `lead-track Widget/` — widget extension
- `Shared/` — code shared across targets
- `lead trackTests/` — unit tests

## Linting

Both linters run automatically as Xcode build phases. To run manually:

```bash
swiftlint              # style and complexity checks
swiftformat --lint .   # formatting check
swiftformat .          # auto-fix formatting
```

## License

[MIT](LICENSE)
