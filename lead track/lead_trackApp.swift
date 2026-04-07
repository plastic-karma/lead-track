import SwiftData
import SwiftUI

@main
struct lead_trackApp: App {
    @Environment(\.scenePhase) private var scenePhase

    var sharedModelContainer: ModelContainer = {
        do {
            return try SharedModelContainer.create()
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            NotificationService.requestPermission()
            NotificationService.rescheduleAll(
                container: sharedModelContainer
            )
        }
    }
}
