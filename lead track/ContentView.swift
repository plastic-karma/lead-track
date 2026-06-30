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
/// Today and Aspirations sit on a native horizontal pager rather than a stock
/// bottom-bar `TabView`, whose selection change just cuts with no animation.
/// A `scrollPosition` binding drives both the swipe and the custom tab bar
/// below it, so a tap slides exactly like a finished swipe does. Swiping is
/// disabled once the active tab has pushed past its root, so it never fights
/// a detail screen's interactive back-swipe.
struct ContentView: View {
    @State private var selectedTab: AppTab? = .today
    @State private var todayPath = NavigationPath()
    @State private var aspirationsPath = NavigationPath()

    var body: some View {
        VStack(spacing: 0) {
            pager
            AppTabBar(selectedTab: animatedSelection)
        }
    }
}

private extension ContentView {
    var pager: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 0) {
                NavigationStack(path: $todayPath) {
                    MetricListView()
                        .appDestinations()
                }
                .containerRelativeFrame(.horizontal)
                .frame(maxHeight: .infinity)
                .id(AppTab.today)

                NavigationStack(path: $aspirationsPath) {
                    AspirationListView()
                        .appDestinations()
                }
                .containerRelativeFrame(.horizontal)
                .frame(maxHeight: .infinity)
                .id(AppTab.aspirations)
            }
            .frame(maxHeight: .infinity)
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $selectedTab)
        .scrollDisabled(!isAtRoot)
        .scrollIndicators(.hidden)
    }

    var isAtRoot: Bool {
        switch selectedTab {
        case .aspirations: aspirationsPath.isEmpty
        case .today, nil: todayPath.isEmpty
        }
    }

    /// Routes tab-bar taps through the same state the pager scrolls on, so a
    /// tap and a swipe settle the same way.
    var animatedSelection: Binding<AppTab> {
        Binding(
            get: { selectedTab ?? .today },
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
