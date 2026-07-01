import SwiftData
import SwiftUI

struct MetricDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let metric: Metric
    @Query private var sessions: [Session]
    @State private var showingProjectForm = false
    @State private var showingDetailedStats = false
    @State private var showingGoalSettings = false
    @State private var showingCountEntry = false
    @State private var showingDurationEntry = false
    @State private var showingAllSessions = false
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

    private var activeSession: Session? {
        sessions.first { $0.isRunning }
    }

    private var activeProjects: [Project] {
        metric.projects
            .filter { $0.status == .active }
            .sorted { $0.startedAt < $1.startedAt }
    }

    private var finishedProjects: [Project] {
        metric.projects
            .filter { $0.status == .finished }
            .sorted { ($0.finishedAt ?? .distantPast) > ($1.finishedAt ?? .distantPast) }
    }

    private var directSessions: [Session] {
        sessions
            .filter { $0.project == nil && !$0.isRunning }
            .sorted { $0.startedAt > $1.startedAt }
    }

    private var visibleDirectSessions: [Session] {
        showingAllSessions
            ? directSessions
            : Array(directSessions.prefix(SessionStatistics.sessionListPreviewLimit))
    }

    private var dailyTotals: [DailyTotal] {
        SessionStatistics.dailyTotals(from: sessions)
    }

    var body: some View {
        let totals = dailyTotals
        List {
            heroSection(totals)
            aspirationsSection
            statisticsSection
            ActivitySection(dailyTotals: totals, tint: metric.displayColor)
            if !activeProjects.isEmpty {
                projectsSection("Active Projects", activeProjects)
            }
            if metric.isHealthLinked {
                healthSections(totals)
            } else if !directSessions.isEmpty {
                directSessionsSections
            }
            if !finishedProjects.isEmpty {
                projectsSection("Finished", finishedProjects)
            }
        }
        .navigationTitle(metric.name)
        .toolbar {
            if !metric.isHealthLinked {
                ToolbarItem {
                    Button { showingProjectForm = true } label: {
                        Label("Add Project", systemImage: "folder.badge.plus")
                    }
                }
            }
            ToolbarItem {
                Button { showingGoalSettings = true } label: {
                    Label("Goals", systemImage: "target")
                }
            }
            ToolbarItem {
                Button { showingEdit = true } label: {
                    Label("Edit Metric", systemImage: "pencil")
                }
            }
        }
        .sheet(isPresented: $showingProjectForm) {
            ProjectFormView(metric: metric)
        }
        .sheet(isPresented: $showingDetailedStats) {
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
        .sheet(isPresented: $showingGoalSettings) {
            GoalSettingsView(metric: metric)
        }
        .sheet(isPresented: $showingEdit) {
            MetricFormView(metric: metric)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingCountEntry) {
            CountEntryView(metric: metric, project: nil)
        }
        .sheet(isPresented: $showingDurationEntry) {
            DurationEntryView(metric: metric, project: nil)
        }
        .sheet(item: $sessionToMove) { session in
            MoveSessionView(session: session)
        }
        .recordingFeedback(isActive: activeSession != nil)
        .task(id: metric.stableID) {
            await refreshHealth()
        }
    }
}

// MARK: - Sections

extension MetricDetailView {
    private func heroSection(_ totals: [DailyTotal]) -> some View {
        Section {
            MetricHeroView(
                metric: metric,
                activeSession: activeSession,
                todayTotal: SessionStatistics.todayTotal(from: totals),
                onLogManually: showManualEntry
            )
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            descriptionRow
        } footer: {
            defaultProjectFooter
        }
    }

    @ViewBuilder
    private var descriptionRow: some View {
        if let text = metric.metricDescription, !text.isEmpty {
            Text(text)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
        }
    }

    @ViewBuilder
    private var aspirationsSection: some View {
        if !metric.aspirations.isEmpty {
            Section("Part of") {
                AspirationChipsRow(
                    aspirations: metric.aspirations.sorted { $0.createdAt < $1.createdAt }
                )
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }
        }
    }

    private var statisticsSection: some View {
        StatisticsView(
            sessions: sessions,
            measurementType: metric.measurementType,
            unit: metric.unit,
            weeklyGoal: metric.weeklyGoal,
            excludedWeekdays: metric.excludedWeekdays,
            showingDetailedStats: $showingDetailedStats,
            tint: metric.displayColor
        )
    }

    @ViewBuilder
    private var defaultProjectFooter: some View {
        if let project = metric.defaultProject {
            Label(
                "Logging to \(project.name)",
                systemImage: "star.fill"
            )
        }
    }

    private func projectsSection(
        _ title: String,
        _ projects: [Project]
    ) -> some View {
        Section(title) {
            ForEach(projects) { project in
                NavigationLink(value: project) {
                    projectRow(project)
                }
            }
            .onDelete { offsets in
                deleteProjects(offsets, from: projects)
            }
        }
    }

    /// A health metric's history is read-only: mirrored day rows instead of
    /// editable sessions, plus where the numbers come from.
    @ViewBuilder
    private func healthSections(_ totals: [DailyTotal]) -> some View {
        HealthHistorySection(metric: metric, dailyTotals: totals)
        HealthLinkSection(
            metric: metric,
            hasRecentData: SessionStatistics.windowedTotal(days: 30, from: totals) > 0
        )
    }

    @ViewBuilder
    private var directSessionsSections: some View {
        ForEach(SessionDayGrouping.group(visibleDirectSessions)) { group in
            sessionDaySection(group)
        }
        expandSection
    }

    private func sessionDaySection(_ group: SessionDayGroup) -> some View {
        Section(SessionDayGrouping.label(for: group.day)) {
            ForEach(group.sessions) { session in
                sessionRow(session)
            }
            .onDelete { offsets in
                deleteSessions(offsets, in: group)
            }
        }
    }

    @ViewBuilder
    private var expandSection: some View {
        if directSessions.count > SessionStatistics.sessionListPreviewLimit {
            Section {
                SessionListExpandButton(
                    totalCount: directSessions.count,
                    isExpanded: $showingAllSessions
                )
            }
        }
    }
}

// MARK: - Helpers

extension MetricDetailView {
    private func projectRow(_ project: Project) -> some View {
        HStack {
            Text(project.name)
            if project.isDefault {
                Image(systemName: "star.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Default project")
            }
            Spacer()
            if project.sessions.contains(where: \.isRunning) {
                Image(systemName: "record.circle")
                    .foregroundStyle(metric.displayColor)
                    .symbolEffect(.pulse)
            }
            Text("\(project.sessions.count) sessions")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func sessionRow(_ session: Session) -> some View {
        SessionRowView(session: session, showsDate: false)
            .swipeActions(edge: .leading) {
                if !metric.projects.isEmpty {
                    Button { sessionToMove = session } label: {
                        Label("Move", systemImage: "folder")
                    }
                    .tint(.blue)
                }
            }
    }

    private func showManualEntry() {
        if metric.measurementType == .duration {
            showingDurationEntry = true
        } else {
            showingCountEntry = true
        }
    }

    /// Freshens the mirror whenever a health metric's detail opens; silent,
    /// so it never surfaces a permission prompt on navigation.
    private func refreshHealth() async {
        guard metric.isHealthLinked, let id = metric.stableID else { return }
        await HealthMetricSyncService.shared.refreshMetric(
            metricID: id, container: modelContext.container
        )
    }

    private func deleteProjects(
        _ offsets: IndexSet,
        from projects: [Project]
    ) {
        withAnimation {
            for index in offsets {
                modelContext.delete(projects[index])
            }
        }
    }

    private func deleteSessions(
        _ offsets: IndexSet,
        in group: SessionDayGroup
    ) {
        withAnimation {
            for index in offsets {
                modelContext.delete(group.sessions[index])
            }
        }
    }
}
