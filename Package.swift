// swift-tools-version: 6.1

// Overlay package for non-Mac development. The Xcode project stays the source
// of truth for app builds; this package compiles the platform-neutral subset
// of Shared/ (and its tests) with the open-source Swift toolchain so domain
// logic can be built and tested on Linux — and, on a macOS runner, the
// SwiftData-backed services and their suites too, giving SessionService,
// ProjectService, and the watch-action pipeline an executing test runner
// (CI's simulator-based test step is skipped whenever the image ships no
// bootable simulator).
//
// The overlay build defines LEADTRACK_OVERLAY: sources use it to compile out
// framework calls that need a real app bundle at runtime (UserNotifications
// scheduling), which would crash an unbundled SwiftPM test process on macOS.

import PackageDescription

/// AppIntents/WidgetKit surfaces are never part of the overlay.
let appleOnlySources = [
    "Services/StartTimerIntent.swift",
    "Services/StopTimerIntent.swift"
]

/// SwiftData-backed services and their suites: compiled and run wherever
/// SwiftData exists (macOS), excluded only on Linux.
let swiftDataSources = [
    "Services/SessionService.swift",
    "Services/SharedModelContainer.swift",
    "Services/WatchActionHandler.swift",
    "Services/WatchSnapshotBuilder.swift"
]
let swiftDataTests = [
    "CountdownReconcileTests.swift",
    "DefaultProjectTests.swift",
    "RecordingCommitTests.swift",
    "SessionMoveTests.swift",
    "WatchActionHandlerTests.swift",
    "WatchSnapshotBuilderTests.swift"
]

#if os(macOS)
let sourceExcludes = appleOnlySources
let testExcludes = [String]()
#else
let sourceExcludes = appleOnlySources + swiftDataSources
let testExcludes = swiftDataTests
#endif

let package = Package(
    name: "lead-track",
    platforms: [.macOS(.v15)],
    targets: [
        .target(
            name: "lead_track",
            path: "Shared",
            exclude: sourceExcludes,
            swiftSettings: [
                .swiftLanguageMode(.v5),
                .define("LEADTRACK_OVERLAY")
            ]
        ),
        .testTarget(
            name: "LeadTrackTests",
            dependencies: ["lead_track"],
            path: "lead trackTests",
            exclude: testExcludes,
            swiftSettings: [
                .swiftLanguageMode(.v5),
                .define("LEADTRACK_OVERLAY")
            ]
        )
    ]
)
