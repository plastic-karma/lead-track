import SwiftData
import SwiftUI

/// The metric detail as one calm column under a wash of the metric's color:
/// the title row wearing the icon and aspiration links, the ring instrument
/// (today nested in the week, pace as a notch), a quiet all-time line, and
/// the fold rows — Activity, History, Projects — that expand in place. The
/// record dock floats at the bottom; occasional actions live in the toolbar.
struct MetricDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let metric: Metric
    @Query private var sessions: [Session]
    @Query(sort: \Aspiration.createdAt) private var allAspirations: [Aspiration]
    @State private var showingProjectForm = false
    @State private var showingDetailedStats = false
    @State private var showingGoalSettings = false
    @State private var showingCalendar = false
    @State private var showingCountEntry = false
    @State private var showingDurationEntry = false
    @State private var showingEdit = false
    @State private var sessionToMove: Session?

    init(metric: Metric) {
        self.metric = metric
        let id = metric.persistentModelID
        _sessions = Query(
            filter: #Predicate<Session> {
                $0.metric?.persistentModelID == id
            },
            sort: \.startedAt
        )
    }

    var body: some View {
        page
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            .safeAreaInset(edge: .bottom) { dock }
            .sheet(isPresented: $showingProjectForm) { ProjectFormView(metric: metric) }
            .sheet(isPresented: $showingDetailedStats) { detailedStats }
            .sheet(isPresented: $showingGoalSettings) { GoalSettingsView(metric: metric) }
            .sheet(isPresented: $showingCalendar) { GoalCalendarView(filter: .metric(metric)) }
            .sheet(isPresented: $showingEdit) { editSheet }
            .sheet(isPresented: $showingCountEntry) { CountEntryView(metric: metric, project: nil) }
            .sheet(isPresented: $showingDurationEntry) { DurationEntryView(metric: metric, project: nil) }
            .sheet(item: $sessionToMove) { MoveSessionView(session: $0) }
            .recordingFeedback(isActive: activeSession != nil)
            .task(id: metric.stableID) {
                await refreshHealth()
            }
    }

    private var tint: Color {
        metric.displayColor
    }
}

// MARK: - Data

extension MetricDetailView {
    private var activeSession: Session? {
        sessions.first(where: \.isRunning)
    }

    private var directSessions: [Session] {
        sessions
            .filter { $0.project == nil && !$0.isRunning }
            .sorted { $0.startedAt > $1.startedAt }
    }

    private var dailyTotals: [DailyTotal] {
        SessionStatistics.dailyTotals(from: sessions)
    }

    /// The aspirations this metric is poured into. Read from the forward
    /// relationship (`Aspiration.metrics`) rather than the `metric.aspirations`
    /// back-array: SwiftData doesn't reliably populate the many-to-many inverse
    /// when only the aspiration side is ever written, so the back-array reads
    /// empty. Mirrors how the Today footer and `AspirationRollup` read effort,
    /// and stays reactive as links change.
    private var connectedAspirations: [Aspiration] {
        allAspirations.filter { aspiration in
            aspiration.metrics.contains(where: { $0 === metric })
        }
    }
}

// MARK: - Page

extension MetricDetailView {
    private var page: some View {
        ScrollView {
            column
        }
        .background(washBackground)
    }

    private var column: some View {
        let totals = dailyTotals
        return VStack(alignment: .leading, spacing: 14) {
            titleBlock
            archivedBanner
            ringCard(totals)
            MetricQuietLines(metric: metric, dailyTotals: totals)
            foldsCard(totals)
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 24)
    }

    private func ringCard(_ totals: [DailyTotal]) -> some View {
        MetricRingCard(
            metric: metric,
            activeSession: activeSession,
            todayTotal: SessionStatistics.todayTotal(from: totals),
            weekTotal: SessionStatistics.currentWeekTotal(from: totals)
        )
    }

    private func foldsCard(_ totals: [DailyTotal]) -> some View {
        MetricFoldsCard(
            metric: metric,
            dailyTotals: totals,
            directSessions: directSessions,
            onMoveSession: { sessionToMove = $0 }
        )
    }

    /// The metric's color washing down from the top, the same atmosphere the
    /// aspiration screens open with.
    private var washBackground: some View {
        Theme.screenBackground
            .overlay(alignment: .top) {
                Theme.wash(tint, peak: 0.14)
                    .frame(height: 280)
            }
            .ignoresSafeArea()
    }

    @ViewBuilder
    private var dock: some View {
        if !metric.isHealthLinked, !metric.isArchived {
            MetricRecordDock(
                metric: metric,
                activeSession: activeSession,
                onLogManually: showManualEntry
            )
        }
    }

    /// The quiet notice an archived metric wears in place of its record
    /// dock: where it went, and the way back.
    @ViewBuilder
    private var archivedBanner: some View {
        if metric.isArchived {
            HStack(spacing: 8) {
                Image(systemName: "archivebox")
                Text("Archived — resting off Today and Week.")
                Spacer(minLength: 8)
                Button("Unarchive") { toggleArchive() }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 4)
        }
    }
}

// MARK: - Title Block

extension MetricDetailView {
    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                MetricIcon(systemName: metric.displayIcon, tint: tint, size: 40)
                Text(metric.name)
                    .font(.title2.weight(.bold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 8)
                if let aspiration = connectedAspirations.first, connectedAspirations.count == 1 {
                    chipLink(aspiration)
                }
            }
            if connectedAspirations.count > 1 {
                AspirationChipsRow(aspirations: connectedAspirations)
            }
            description
        }
        .padding(.horizontal, 4)
    }

    private func chipLink(_ aspiration: Aspiration) -> some View {
        NavigationLink(value: aspiration) {
            AspirationChip(aspiration: aspiration)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var description: some View {
        if let text = metric.metricDescription, !text.isEmpty {
            Text(text)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Toolbar & Sheets

extension MetricDetailView {
    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        if !metric.isHealthLinked {
            ToolbarItem { FavoriteMetricButton(metric: metric) }
        }
        ToolbarItem {
            Menu {
                Button("Edit Metric", systemImage: "pencil") { showingEdit = true }
                Button("Goals & Reminders", systemImage: "target") { showingGoalSettings = true }
                if !dailyTotals.isEmpty {
                    Button("All Statistics", systemImage: "chart.bar.xaxis") {
                        showingDetailedStats = true
                    }
                }
                Button("Calendar", systemImage: "calendar") { showingCalendar = true }
                if !metric.isHealthLinked {
                    Button("Add Project", systemImage: "folder.badge.plus") {
                        showingProjectForm = true
                    }
                }
                Divider()
                Button(
                    metric.isArchived ? "Unarchive" : "Archive",
                    systemImage: metric.isArchived ? "tray.and.arrow.up" : "archivebox"
                ) {
                    toggleArchive()
                }
            } label: {
                Label("More", systemImage: "ellipsis.circle")
            }
        }
    }

    private var detailedStats: some View {
        DetailedStatisticsView(
            dailyTotals: dailyTotals,
            measurementType: metric.measurementType,
            unit: metric.unit,
            dailyGoal: metric.dailyGoal,
            weeklyGoal: metric.weeklyGoal,
            excludedWeekdays: metric.excludedWeekdays,
            tint: metric.displayColor
        )
    }

    private var editSheet: some View {
        MetricFormView(metric: metric)
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
    }

    private func showManualEntry() {
        if metric.measurementType == .duration {
            showingDurationEntry = true
        } else {
            showingCountEntry = true
        }
    }

    /// Sets the metric aside or brings it back. Archiving first stops any
    /// running timer — a session on an archived metric would be invisible on
    /// every surface — and both directions re-arm notifications (cancelled
    /// while archived); the watch refreshes on the save that follows.
    private func toggleArchive() {
        withAnimation(.snappy) {
            if metric.isArchived {
                metric.unarchive()
            } else {
                SessionService.stopSession(for: metric)
                metric.archive()
            }
        }
        NotificationService.rescheduleMetric(metric)
    }

    /// Freshens the mirror whenever a health metric's detail opens; silent,
    /// so it never surfaces a permission prompt on navigation.
    private func refreshHealth() async {
        guard metric.isHealthLinked, let id = metric.stableID else { return }
        await HealthMetricSyncService.shared.refreshMetric(
            metricID: id, container: modelContext.container
        )
    }
}
