import SwiftData
import SwiftUI

/// The app root: a two-tab shell elevating aspirations to a peer of daily
/// tracking. Each tab owns its own `NavigationStack`, and all three drill-in
/// destinations are registered on both — the Aspirations tab drills into metric
/// and project screens, and their back-link chips (reachable from Today)
/// navigate to an aspiration. Cross-tab links push on the current stack rather
/// than switching tabs.
struct ContentView: View {
    var body: some View {
        TabView {
            Tab("Today", systemImage: "square.stack.3d.up.fill") {
                NavigationStack {
                    MetricListView()
                        .appDestinations()
                }
            }
            Tab("Aspirations", systemImage: "mountain.2") {
                NavigationStack {
                    AspirationListView()
                        .appDestinations()
                }
            }
        }
    }
}

private extension View {
    /// The shared drill-in destinations, applied to every tab's stack.
    func appDestinations() -> some View {
        navigationDestination(for: Metric.self) { metric in
            MetricDetailView(metric: metric)
        }
        .navigationDestination(for: Project.self) { project in
            ProjectDetailView(project: project)
        }
        .navigationDestination(for: Aspiration.self) { aspiration in
            AspirationDetailView(aspiration: aspiration)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(
            for: [Metric.self, Project.self, Session.self, Aspiration.self],
            inMemory: true
        )
}
