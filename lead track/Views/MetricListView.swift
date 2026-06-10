import SwiftData
import SwiftUI

/// The "Today" dashboard: a scrolling stack of living metric cards under a
/// date-and-goal-rings header. Cards show today's value and act in place;
/// tapping a card still navigates to the metric's detail screen.
struct MetricListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Metric.createdAt) private var metrics: [Metric]
    @Query(filter: #Predicate<Session> { $0.endedAt == nil })
    private var runningSessions: [Session]
    @State private var showingAddSheet = false
    @State private var showingWeeklyReview = false
    @State private var showingExport = false
    @State private var showingImport = false
    @State private var showingSettings = false

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                TodayHeaderView(metrics: metrics)
                ForEach(metrics) { metric in
                    metricCard(metric)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .background(Theme.screenBackground)
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
        .sheet(isPresented: $showingWeeklyReview) {
            WeeklyReviewView()
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
                    "No Metrics",
                    systemImage: "chart.bar",
                    description: Text("Tap + to add a metric.")
                )
            }
        }
    }
}

// MARK: - Pieces

extension MetricListView {
    private var appMenu: some View {
        Menu {
            Button { showingSettings = true } label: {
                Label("Settings", systemImage: "gear")
            }
            Button { showingWeeklyReview = true } label: {
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
