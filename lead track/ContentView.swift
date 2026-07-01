import SwiftData
import SwiftUI

/// The two screens `ContentView` pages between. Lives at file scope (rather
/// than nested) so `AppTabBar` can share it.
enum AppTab: Hashable {
    case today
    case aspirations
}

/// The app root: a two-tab shell elevating aspirations to a peer of daily
/// tracking. Each tab owns its own `NavigationStack`, and all three drill-in
/// destinations are registered on both — the Aspirations tab drills into metric
/// and project screens, and their back-link chips (reachable from Today)
/// navigate to an aspiration. Cross-tab links push on the current stack rather
/// than switching tabs.
///
/// Today and Aspirations sit on a page-style `TabView` so each whole screen
/// slides into place on a swipe (and, driven through the same selection, on a
/// tap of the custom `AppTabBar` below). A `.page` style is used rather than a
/// hand-rolled horizontal `ScrollView`: it keeps each `NavigationStack` a
/// top-level page, so their large-title bars keep the standard leading margin
/// that a nested scroll view would otherwise collapse. The built-in page dots
/// are hidden since `AppTabBar` is the visible affordance.
struct ContentView: View {
    @State private var selectedTab: AppTab = .today
    @State private var todayPath = NavigationPath()
    @State private var aspirationsPath = NavigationPath()

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $selectedTab) {
                NavigationStack(path: $todayPath) {
                    MetricListView()
                        .appDestinations()
                }
                .tag(AppTab.today)

                NavigationStack(path: $aspirationsPath) {
                    AspirationListView()
                        .appDestinations()
                }
                .tag(AppTab.aspirations)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            AppTabBar(selectedTab: animatedSelection)
        }
    }
}

private extension ContentView {
    /// Tab-bar taps animate the page transition (a swipe already slides
    /// natively), so a tap settles the same way a finished swipe does.
    var animatedSelection: Binding<AppTab> {
        Binding(
            get: { selectedTab },
            set: { newValue in
                withAnimation(.snappy) {
                    selectedTab = newValue
                }
            }
        )
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
