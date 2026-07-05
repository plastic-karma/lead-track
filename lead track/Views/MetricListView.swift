import SwiftData
import SwiftUI

/// The "Today" dashboard: aspiration clusters under a segmented day-dial
/// header. Clusters with something to do today open full, neediest first;
/// resting, done, and self-filling clusters compress into one-line stubs
/// (see `TodayClusterSections`), so the screen gets quieter as the day is
/// completed. Rows act in place; tapping one still navigates to the metric.
struct MetricListView: View {
    /// Internal (not private) so the cluster arrangement in its own file can
    /// render under the same queries.
    @Query(sort: \Metric.createdAt) var metrics: [Metric]
    @Query(sort: \Aspiration.createdAt) var aspirations: [Aspiration]
    @Query(sort: \Intention.createdAt) var intentions: [Intention]
    @Query(filter: Session.isRunningPredicate) var runningSessions: [Session]
    /// Which stub clusters are expanded inline — per-cluster and transient
    /// by design, so tomorrow always starts folded.
    @State var expandedStubs: Set<String> = []
    @State private var showingAddSheet = false
    /// Raising the responder's review flag slides the app to the Week tab
    /// (see `ContentView`) — the same route a tapped weekly notification
    /// takes, so the menu entry and the notification land identically.
    @ObservedObject private var notificationResponder = NotificationResponder.shared
    @State private var showingExport = false
    @State private var showingImport = false
    @State private var showingSettings = false

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                DayDialView(metrics: metrics)
                clusterSections
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .background(Theme.washedScreen)
        .navigationTitle("Today")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                appMenu
            }
            ToolbarItem {
                Button { showingAddSheet = true } label: {
                    Label("Add Metric", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            MetricFormView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingExport) {
            DataExportView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingImport) {
            DataImportView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingSettings) {
            AppSettingsView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .overlay {
            if showsEmptyState {
                ContentUnavailableView(
                    "Begin Something",
                    systemImage: "mountain.2",
                    description: Text(
                        "Add something you want to pour yourself into. Tap + to start."
                    )
                )
            }
        }
    }
}

// MARK: - Pieces

extension MetricListView {
    /// Nothing to cluster at all — no metrics and no open intentions this
    /// week — so the day opens with the invitation instead.
    private var showsEmptyState: Bool {
        metrics.isEmpty && !intentions.contains { $0.isOpen && $0.isInCurrentWeek() }
    }

    private var appMenu: some View {
        Menu {
            Button { showingSettings = true } label: {
                Label("Settings", systemImage: "gear")
            }
            Button { notificationResponder.showWeeklyReview = true } label: {
                Label("Weekly Review", systemImage: "calendar.badge.clock")
            }
            Button { showingExport = true } label: {
                Label("Export Data", systemImage: "square.and.arrow.up")
            }
            Button { showingImport = true } label: {
                Label("Import Data", systemImage: "square.and.arrow.down")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
    }
}
