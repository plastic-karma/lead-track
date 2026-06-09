import SwiftData
import SwiftUI

@main
struct lead_trackApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var lockService = AppLockService()

    var sharedModelContainer: ModelContainer = {
        let isUITest = ProcessInfo.processInfo.arguments.contains("-uitest")
        do {
            return try SharedModelContainer.create(inMemoryOnly: isUITest)
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    init() {
        // Activate in init, not on scene phase: the system may launch the app
        // in the background to deliver a queued watch action.
        PhoneWatchSyncService.shared.activate(container: sharedModelContainer)
    }

    var body: some Scene {
        WindowGroup {
            content
                .modelContainer(sharedModelContainer)
        }
        .onChange(of: scenePhase) { _, phase in
            handle(phase: phase)
        }
    }

    @ViewBuilder
    private var content: some View {
        if lockService.isLocked {
            AppLockView(service: lockService)
        } else if scenePhase != .active && lockService.isEnabled {
            AppSwitcherCover()
        } else {
            ContentView()
        }
    }

    private func handle(phase: ScenePhase) {
        lockService.handleScenePhase(phase)
        guard phase == .active else {
            PhoneWatchSyncService.shared.pushSnapshot()
            return
        }
        SessionService.syncLiveActivity(
            in: ModelContext(sharedModelContainer)
        )
        NotificationService.requestPermission()
        NotificationService.rescheduleAll(
            container: sharedModelContainer
        )
    }
}
