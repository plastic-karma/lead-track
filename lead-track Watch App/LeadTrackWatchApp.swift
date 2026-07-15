import SwiftUI
import WatchKit

/// Activates WatchConnectivity on every launch — including the headless
/// background launch a complication push triggers — before any scene renders.
/// `@State`-driven activation would be too late: its initializer runs only when
/// SwiftUI first evaluates the scene body, which a background wake may skip, so
/// the queued snapshot would never be delivered and the complications would
/// stay frozen. Activating in the delegate makes the wake reliably land.
final class WatchAppDelegate: NSObject, WKApplicationDelegate {
    func applicationDidFinishLaunching() {
        WatchSyncController.shared.activate()
    }
}

@main
struct LeadTrackWatchApp: App {
    @WKApplicationDelegateAdaptor(WatchAppDelegate.self) private var delegate
    @Environment(\.scenePhase) private var scenePhase
    @State private var sync = WatchSyncController.shared

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
