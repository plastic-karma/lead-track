import SwiftData
import SwiftUI

@main
struct lead_trackApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var lockService = AppLockService()

    let sharedModelContainer: ModelContainer = {
        let isUITest = ProcessInfo.processInfo.arguments.contains("-uitest")
        do {
            return try SharedModelContainer.create(inMemoryOnly: isUITest)
        } catch {
            // A failed open (most plausibly a future migration failure) must
            // stay diagnosable, not become a crash loop that also blocks
            // recovery. Launch on a volatile in-memory store instead: the
            // on-disk data is left untouched for a fixed build to migrate,
            // and the failure is in the log rather than a crash report.
            StoreLog.error("Persistent store failed to open; launching in-memory: \(error)")
            do {
                return try SharedModelContainer.create(inMemoryOnly: true)
            } catch {
                fatalError("Could not create any ModelContainer: \(error)")
            }
        }
    }()

    init() {
        // Activate in init, not on scene phase: the system may launch the app
        // in the background to deliver a queued watch action.
        PhoneWatchSyncService.shared.activate(container: sharedModelContainer)
        // Likewise the notification delegate, so a tap that launches the app
        // still deep-links.
        NotificationResponder.shared.install()
        // Stop any countdown that ran out while the app was closed, and watch
        // for ones that reach zero while it's open.
        CountdownCoordinator.shared.activate(container: sharedModelContainer)
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
        if phase == .background {
            PhoneWatchSyncService.shared.pushSnapshot()
            // Leaving the app is the moment sessions completed while it was
            // open get sent to Apple Health. No-op until a metric exports.
            exportSessionsToHealth()
        }
        guard phase == .active else { return }
        CountdownCoordinator.shared.reconcile()
        SessionService.syncLiveActivity(
            in: ModelContext(sharedModelContainer)
        )
        NotificationService.requestPermission()
        // The reschedule sweep walks every metric's session history; a
        // detached task keeps it out of the scene-activation turn.
        let container = sharedModelContainer
        Task.detached {
            await NotificationService.rescheduleAll(container: container)
        }
        // No-op until the user has created a health-linked metric; only then
        // does the app talk to HealthKit at all.
        Task {
            await HealthMetricSyncService.shared.refreshAll(container: container)
        }
        // Becoming active also catches sessions completed elsewhere — from
        // the watch, a widget, or an auto-stopped countdown.
        exportSessionsToHealth()
    }

    private func exportSessionsToHealth() {
        let container = sharedModelContainer
        Task {
            await HealthSessionExportService.shared.exportAll(container: container)
        }
    }
}
