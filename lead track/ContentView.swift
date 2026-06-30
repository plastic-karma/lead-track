import SwiftData
import SwiftUI

/// The app root: a two-tab shell elevating aspirations to a peer of daily
/// tracking. Each tab owns its own `NavigationStack`, and all three drill-in
/// destinations are registered on both — the Aspirations tab drills into metric
/// and project screens, and their back-link chips (reachable from Today)
/// navigate to an aspiration. Cross-tab links push on the current stack rather
/// than switching tabs.
///
/// Today and Aspirations also swipe against each other, on top of tapping the
/// tab bar. The swipe only acts while the active tab is at its root, so it
/// never competes with a pushed detail screen's interactive back-swipe.
struct ContentView: View {
    private enum AppTab: Hashable {
        case today
        case aspirations
    }

    @State private var selectedTab: AppTab = .today
    @State private var todayPath = NavigationPath()
    @State private var aspirationsPath = NavigationPath()

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Today", systemImage: "square.stack.3d.up.fill", value: .today) {
                NavigationStack(path: $todayPath) {
                    MetricListView()
                        .appDestinations()
                }
            }
            Tab("Aspirations", systemImage: "mountain.2", value: .aspirations) {
                NavigationStack(path: $aspirationsPath) {
                    AspirationListView()
                        .appDestinations()
                }
            }
        }
        .simultaneousGesture(swipeBetweenTabsGesture)
    }

    private var isAtRoot: Bool {
        switch selectedTab {
        case .today: todayPath.isEmpty
        case .aspirations: aspirationsPath.isEmpty
        }
    }

    /// A simultaneous gesture so it never steals touches from the scroll
    /// views, lists, or row swipe actions already living in each tab.
    private var swipeBetweenTabsGesture: some Gesture {
        DragGesture(minimumDistance: 40)
            .onEnded { value in
                guard isAtRoot else { return }
                let translation = value.translation
                guard abs(translation.width) > abs(translation.height) * 2 else { return }
                selectedTab = translation.width < 0 ? .aspirations : .today
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
