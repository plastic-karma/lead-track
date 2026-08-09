import SwiftData
import SwiftUI

/// The three screens `ContentView` pages between — the app's three
/// timescales: the day, the week, and the lifetime. Lives at file scope
/// (rather than nested) so `AppTabBar` can share it.
enum AppTab: Hashable {
    case today
    case week
    case aspirations
}

private struct AdditionalReviewRoute: Identifiable {
    let id: UUID
}

/// The app root: a three-tab shell — Today (the day), Week (the weekly
/// review and intentions), Aspirations (the lifetime). Each tab owns its own
/// `NavigationStack`, and all three drill-in destinations are registered on
/// every stack — the Aspirations tab drills into metric and project screens,
/// and their back-link chips (reachable from Today) navigate to an
/// aspiration. Cross-tab links push on the current stack rather than
/// switching tabs.
///
/// The tabs sit on a page-style `TabView` so each whole screen slides into
/// place on a swipe (and, driven through the same selection, on a tap of the
/// custom `AppTabBar` below). A `.page` style is used rather than a
/// hand-rolled horizontal `ScrollView`: it keeps each `NavigationStack` a
/// top-level page, so their large-title bars keep the standard leading margin
/// that a nested scroll view would otherwise collapse. The built-in page dots
/// are hidden since `AppTabBar` is the visible affordance.
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTab: AppTab = .today
    @State private var todayPath = NavigationPath()
    @State private var weekPath = NavigationPath()
    @State private var aspirationsPath = NavigationPath()
    @State private var additionalReviewRoute: AdditionalReviewRoute?
    /// Notification taps are staged by the responder before the first scene
    /// renders: weekly opens the Week tab, an additional review presents its
    /// period report, and an intention question opens its aspiration.
    private let notificationResponder = NotificationResponder.shared

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $selectedTab) {
                NavigationStack(path: $todayPath) {
                    MetricListView()
                        .appDestinations()
                }
                .tag(AppTab.today)

                NavigationStack(path: $weekPath) {
                    WeeklyReviewView()
                        .appDestinations()
                }
                .tag(AppTab.week)

                NavigationStack(path: $aspirationsPath) {
                    AspirationListView()
                        .appDestinations()
                }
                .tag(AppTab.aspirations)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            AppTabBar(selectedTab: animatedSelection)
        }
        .sheet(item: $additionalReviewRoute) { route in
            NavigationStack {
                AdditionalReviewDetailView(reviewID: route.id)
            }
        }
        .background(Theme.washedScreen)
        .onAppear {
            routeToWeekIfRequested()
            routeToAspirationIfRequested()
            routeToAdditionalReviewIfRequested()
        }
        .onChange(of: notificationResponder.showWeeklyReview) {
            routeToWeekIfRequested()
        }
        .onChange(of: notificationResponder.pendingAspirationID) {
            routeToAspirationIfRequested()
        }
        .onChange(of: notificationResponder.pendingAdditionalReviewID) {
            routeToAdditionalReviewIfRequested()
        }
    }

    /// Consumes the review deep-link flag by switching to the Week tab.
    private func routeToWeekIfRequested() {
        guard notificationResponder.showWeeklyReview else { return }
        withAnimation(.snappy) {
            selectedTab = .week
        }
        notificationResponder.showWeeklyReview = false
    }

    /// Consumes an additional-review notification by presenting that review's
    /// latest completed period. A definition removed since delivery renders
    /// the detail's explicit removed state instead of opening the Weekly Review.
    private func routeToAdditionalReviewIfRequested() {
        guard let id = notificationResponder.pendingAdditionalReviewID else { return }
        notificationResponder.pendingAdditionalReviewID = nil
        additionalReviewRoute = AdditionalReviewRoute(id: id)
    }

    /// Consumes a daily-question tap by landing on the owning aspiration's
    /// detail, replacing whatever the Aspirations stack held. An aspiration
    /// deleted since the ask resolves to nil and the tap degrades to just
    /// opening the app.
    private func routeToAspirationIfRequested() {
        guard let id = notificationResponder.pendingAspirationID else { return }
        notificationResponder.pendingAspirationID = nil
        guard let aspiration = try? Aspiration.find(stableID: id, in: modelContext) else { return }
        withAnimation(.snappy) {
            selectedTab = .aspirations
        }
        aspirationsPath = NavigationPath()
        aspirationsPath.append(aspiration)
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
        .navigationDestination(for: AspirationWeekRoute.self) { route in
            AspirationWeekDetailView(aspiration: route.aspiration, weeksBack: route.weeksBack)
        }
        .navigationDestination(for: AllMetricsRoute.self) { _ in
            AllMetricsView()
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(
            for: [
                Metric.self, Project.self, Session.self,
                Aspiration.self, Principle.self, Intention.self,
                AspirationCheckIn.self, Moment.self, MomentPhoto.self
            ],
            inMemory: true
        )
}
