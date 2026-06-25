// swift-tools-version: 6.1

// Overlay package for non-Mac development. The Xcode project stays the source
// of truth for app builds; this package compiles the platform-neutral subset
// of Shared/ (and its tests) with the open-source Swift toolchain so domain
// logic can be built and tested on Linux. Files listed in `exclude` depend on
// Apple-only frameworks (SwiftUI, SwiftData stores, AppIntents, WidgetKit).

import PackageDescription

let package = Package(
    name: "lead-track",
    targets: [
        .target(
            name: "lead_track",
            path: "Shared",
            exclude: [
                "Services/SessionService.swift",
                "Services/SharedModelContainer.swift",
                "Services/StartTimerIntent.swift",
                "Services/StopTimerIntent.swift",
                "Services/WatchActionHandler.swift",
                "Services/WatchSnapshotBuilder.swift"
            ],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "LeadTrackTests",
            dependencies: ["lead_track"],
            path: "lead trackTests",
            exclude: [
                "CountdownReconcileTests.swift",
                "DefaultProjectTests.swift",
                "SessionMoveTests.swift",
                "WatchActionHandlerTests.swift"
            ],
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
