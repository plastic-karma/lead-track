import SwiftData
import SwiftUI

struct ProjectDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let project: Project
    @Query private var sessions: [Session]
    @State private var showingDetailedStats = false
    @State private var showingCountEntry = false
    @State private var showingDurationEntry = false
    @State private var showingAllSessions = false
    @State private var sessionToMove: Session?

    init(project: Project) {
        self.project = project
        let id = project.persistentModelID
        _sessions = Query(
            filter: #Predicate<Session> {
                $0.project?.persistentModelID == id
            },
            sort: \.startedAt
        )
    }

    private var activeSession: Session? {
        sessions.first { $0.isRunning }
    }

    private var completedSessions: [Session] {
        sessions
            .filter { !$0.isRunning }
            .sorted { $0.startedAt > $1.startedAt }
    }

    private var visibleSessions: [Session] {
        showingAllSessions
            ? completedSessions
            : Array(completedSessions.prefix(SessionStatistics.sessionListPreviewLimit))
    }

    private var metricTint: Color {
        MetricColor.color(named: project.metric?.colorName)
    }

    var body: some View {
        List {
            timerSection
            StatisticsView(
                sessions: sessions,
                measurementType: project.metric?.measurementType ?? .duration,
                unit: project.metric?.unit,
                dailyGoal: nil,
                weeklyGoal: nil,
                excludedWeekdays: [],
                showingDetailedStats: $showingDetailedStats,
                tint: metricTint
            )
            activitySection
            statusSection
            if !completedSessions.isEmpty {
                sessionsSection
            }
        }
        .sheet(isPresented: $showingDetailedStats) {
            DetailedStatisticsView(
                dailyTotals: SessionStatistics.dailyTotals(
                    from: sessions
                ),
                measurementType: project.metric?.measurementType ?? .duration,
                unit: project.metric?.unit,
                dailyGoal: nil,
                weeklyGoal: nil,
                excludedWeekdays: [],
                tint: metricTint
            )
        }
        .sheet(isPresented: $showingCountEntry) {
            if let metric = project.metric {
                CountEntryView(
                    metric: metric,
                    project: project
                )
            }
        }
        .sheet(isPresented: $showingDurationEntry) {
            if let metric = project.metric {
                DurationEntryView(
                    metric: metric,
                    project: project
                )
            }
        }
        .sheet(item: $sessionToMove) { session in
            MoveSessionView(session: session)
        }
        .navigationTitle(project.name)
        .toolbar {
            ToolbarItem(placement: .destructiveAction) {
                Button("Delete", role: .destructive) {
                    deleteProject()
                }
            }
        }
    }
}

// MARK: - Sections

extension ProjectDetailView {
    @ViewBuilder
    private var timerSection: some View {
        if project.metric?.measurementType == .count {
            countSection
        } else {
            durationSection
        }
    }

    private var durationSection: some View {
        Section {
            if let session = activeSession {
                ActiveSessionBanner(session: session)
                Button("Stop Timer", role: .destructive) {
                    SessionService.stopSession(session)
                }
            } else if project.status == .active {
                Button { startTimer() } label: {
                    Label("Start Timer", systemImage: "play.fill")
                }
            }
            if project.status == .active {
                Button { showingDurationEntry = true } label: {
                    Label("Log Manually", systemImage: "plus.circle")
                }
            }
        }
    }

    private var countSection: some View {
        Section {
            if project.status == .active {
                Button { showingCountEntry = true } label: {
                    Label(
                        "Log Entry",
                        systemImage: "plus.circle"
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var activitySection: some View {
        let totals = SessionStatistics.dailyTotals(from: sessions)
        if !totals.isEmpty {
            Section("Activity") {
                CalendarHeatmapView(dailyTotals: totals, tint: metricTint)
            }
        }
    }

    private var statusSection: some View {
        Section {
            if project.status == .active {
                Toggle("Default Project", isOn: defaultBinding)
                Button("Mark as Finished") {
                    finishProject()
                }
            } else {
                Button("Reopen Project") {
                    reopenProject()
                }
            }
        } footer: {
            if project.isDefault {
                Text("New entries logged from the metric are added here automatically.")
            }
        }
    }

    private var defaultBinding: Binding<Bool> {
        Binding(
            get: { project.isDefault },
            set: { ProjectService.setDefault(project, $0) }
        )
    }

    private var sessionsSection: some View {
        Section("Sessions") {
            ForEach(visibleSessions) { session in
                SessionRowView(session: session)
                    .swipeActions(edge: .leading) {
                        Button { sessionToMove = session } label: {
                            Label("Move", systemImage: "folder")
                        }
                        .tint(.blue)
                    }
            }
            .onDelete(perform: deleteSessions)
            SessionListExpandButton(
                totalCount: completedSessions.count,
                isExpanded: $showingAllSessions
            )
        }
    }
}

// MARK: - Actions

extension ProjectDetailView {
    private func startTimer() {
        guard let metric = project.metric else { return }
        withAnimation {
            SessionService.startSession(
                for: metric,
                project: project,
                in: modelContext
            )
        }
    }

    private func finishProject() {
        ProjectService.finish(project)
    }

    private func reopenProject() {
        ProjectService.reopen(project)
    }

    private func deleteProject() {
        modelContext.delete(project)
        dismiss()
    }

    private func deleteSessions(_ offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(visibleSessions[index])
            }
        }
    }
}
