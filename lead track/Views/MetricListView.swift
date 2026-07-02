import SwiftData
import SwiftUI

/// The "Today" dashboard: a scrolling stack of living metric cards under a
/// date-and-goal-rings header. Cards show today's value and act in place;
/// tapping a card still navigates to the metric's detail screen.
struct MetricListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Metric.createdAt) private var metrics: [Metric]
    @Query(sort: \Aspiration.createdAt) private var aspirations: [Aspiration]
    @Query(sort: \Intention.createdAt) private var intentions: [Intention]
    @Query(filter: Session.isRunningPredicate)
    private var runningSessions: [Session]
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
                TodayHeaderView(metrics: metrics)
                if !leftMetrics.isEmpty {
                    sectionHeader(leftTitle)
                    ForEach(leftMetrics) { metricCard($0) }
                }
                if !doneMetrics.isEmpty {
                    sectionHeader("Done Today")
                    ForEach(doneMetrics) { metric in
                        DoneMetricRow(
                            metric: metric,
                            runningSession: runningSession(for: metric)
                        )
                    }
                }
                TodayIntentionsSection(intentions: intentions)
                TodayAspirationsFooter(aspirations: aspirations)
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
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
            if metrics.isEmpty {
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
    /// Metrics still open today — anything without a met daily goal, so a card
    /// stays in reach until its goal is done (or always, for goal-less metrics).
    private var leftMetrics: [Metric] {
        metrics.filter { !isDone($0) }
    }

    /// Metrics that have met today's goal, collapsed into the "Done" section.
    private var doneMetrics: [Metric] {
        metrics.filter(isDone)
    }

    private func isDone(_ metric: Metric) -> Bool {
        GoalSummary.isDailyComplete(metric)
    }

    private var leftTitle: String {
        let count = leftMetrics.count
        let number = count == 1 ? "One" : "\(count)"
        return "\(number) Left Today"
    }

    private func sectionHeader(_ title: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Divider()
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .kerning(0.5)
        }
        .padding(.top, 4)
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

    private func metricCard(_ metric: Metric) -> some View {
        NavigationLink(value: metric) {
            MetricCardView(
                metric: metric,
                runningSession: runningSession(for: metric)
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                delete(metric)
            } label: {
                Label("Delete Metric", systemImage: "trash")
            }
        }
    }

    private func runningSession(for metric: Metric) -> Session? {
        let id = metric.persistentModelID
        return runningSessions.first {
            $0.metric?.persistentModelID == id
        }
    }

    private func delete(_ metric: Metric) {
        withAnimation {
            modelContext.delete(metric)
        }
    }
}
