import SwiftUI

@main
struct LeadTrackWatchApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var sync = WatchSyncController()

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environment(sync)
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            sync.activate()
            sync.requestRefresh()
        }
    }
}
