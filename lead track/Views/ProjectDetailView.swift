import SwiftData
import SwiftUI

struct ProjectDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let project: Project
    @Query private var sessions: [Session]
    @Query(sort: \Aspiration.createdAt) private var allAspirations: [Aspiration]
    @State private var showingDetailedStats = false
    @State private var showingCalendar = false
    @State private var showingCountEntry = false
    @State private var showingDurationEntry = false
    @State private var showingAllSessions = false
    @State private var showingDeleteConfirmation = false
    @State private var showingClosingMoment = false
    @State private var sessionToMove: Session?
    @State private var deletionErrorMessage = ""
    @State private var showingDeletionError = false

    init(project: Project) {
        self.project = project
        let id = project.persistentModelID
        _sessions = Query(
            filter: #Predicate<Session> {
                $0.project?.persistentModelID == id
            },
            sort: \.startedAt,
            order: .reverse
        )
    }

    private var activeSession: Session? {
        sessions.first { $0.isRunning }
    }

    /// Completed sessions, newest first — the query already sorts descending,
    /// so no per-render re-sort.
    private var completedSessions: [Session] {
        sessions.filter { !$0.isRunning }
    }

    private var metricTint: Color {
        MetricColor.color(named: project.metric?.colorName)
    }

    /// The aspirations this project is poured into. Read from the forward
    /// relationship (`Aspiration.projects`) rather than the
    /// `project.aspirations` back-array: SwiftData doesn't reliably populate
    /// the many-to-many inverse when only the aspiration side is written, so
    /// the back-array reads empty. Mirrors `MetricDetailView`.
    private var connectedAspirations: [Aspiration] {
        allAspirations.filter { aspiration in
            aspiration.projects.contains(where: { $0 === project })
        }
    }

    private var closingMomentOwners: [Aspiration] {
        ProjectService.closingMomentOwners(for: project, among: allAspirations)
    }

    var body: some View {
        let completed = completedSessions
        List {
            ProjectRecordingSection(
                project: project, activeSession: activeSession,
                showingCountEntry: $showingCountEntry, showingDurationEntry: $showingDurationEntry
            )
            ProjectAspirationsSection(aspirations: connectedAspirations)
            StatisticsView(
                sessions: sessions,
                measurementType: project.metric?.measurementType ?? .duration,
                unit: project.metric?.unit,
                weeklyGoal: nil,
                excludedWeekdays: [],
                showingDetailedStats: $showingDetailedStats,
                tint: metricTint
            )
            ActivitySection(
                dailyTotals: SessionStatistics.dailyTotals(from: sessions),
                measurementType: project.metric?.measurementType ?? .duration,
                unit: project.metric?.unit, tint: metricTint
            )
            ProjectStatusSection(project: project, onFinish: finishProject, onReopen: reopenProject)
            if !completed.isEmpty {
                ProjectSessionsSection(
                    completedSessions: completed, isExpanded: $showingAllSessions,
                    onMove: { sessionToMove = $0 }
                )
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
        .sheet(isPresented: $showingCalendar) {
            GoalCalendarView(filter: .project(project))
        }
        .sheet(isPresented: $showingClosingMoment) {
            let owners = closingMomentOwners
            MomentFormView(
                aspiration: owners.count == 1
                    ? owners.first
                    : nil,
                project: project,
                prompt: ProjectService.closingMomentPrompt
            )
        }
        .navigationTitle(project.name)
        .toolbar {
            ToolbarItem {
                Button { showingCalendar = true } label: {
                    Label("Calendar", systemImage: "calendar")
                }
            }
            ToolbarItem(placement: .destructiveAction) {
                Button("Delete", role: .destructive) {
                    showingDeleteConfirmation = true
                }
            }
        }
        .confirmationDialog(
            "Delete \(project.name)?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Project", role: .destructive, action: deleteProject)
        } message: {
            Text("Every session logged in this project is deleted with it. This can't be undone.")
        }
        .alert("Couldn't delete project", isPresented: $showingDeletionError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(deletionErrorMessage)
        }
    }
}

// MARK: - Sections

private struct ProjectRecordingSection: View {
    @Environment(\.modelContext) private var modelContext
    let project: Project
    let activeSession: Session?
    @Binding var showingCountEntry: Bool
    @Binding var showingDurationEntry: Bool

    var body: some View {
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
}

private struct ProjectAspirationsSection: View {
    let aspirations: [Aspiration]

    var body: some View {
        if !aspirations.isEmpty {
            Section("Part of") {
                AspirationChipsRow(aspirations: aspirations)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }
        }
    }
}

private struct ProjectStatusSection: View {
    let project: Project
    let onFinish: () -> Void
    let onReopen: () -> Void

    var body: some View {
        Section {
            if project.status == .active {
                Toggle("Default Project", isOn: defaultBinding)
                Button("Mark as Finished") {
                    onFinish()
                }
            } else {
                Button("Reopen Project") {
                    onReopen()
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
}

private struct ProjectSessionsSection: View {
    @Environment(\.modelContext) private var modelContext
    let completedSessions: [Session]
    @Binding var isExpanded: Bool
    let onMove: (Session) -> Void

    private var visibleSessions: ArraySlice<Session> {
        completedSessions.prefix(isExpanded ? completedSessions.count : SessionStatistics.sessionListPreviewLimit)
    }

    var body: some View {
        Section("Sessions") {
            ForEach(visibleSessions) { session in
                SessionRowView(session: session)
                    .swipeActions(edge: .leading) {
                        Button { onMove(session) } label: {
                            Label("Move", systemImage: "folder")
                        }
                        .tint(.blue)
                    }
            }
            .onDelete(perform: deleteSessions)
            SessionListExpandButton(
                totalCount: completedSessions.count,
                isExpanded: $isExpanded
            )
        }
    }

    private func deleteSessions(_ offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(visibleSessions[index])
            }
        }
    }
}

// MARK: - Actions

extension ProjectDetailView {
    private func finishProject() {
        ProjectService.finish(project)
        showingClosingMoment = !closingMomentOwners.isEmpty
    }

    private func reopenProject() {
        ProjectService.reopen(project)
    }

    private func deleteProject() {
        do {
            try modelContext.deleteProjectAndDependents(project)
            dismiss()
        } catch {
            deletionErrorMessage = error.localizedDescription
            showingDeletionError = true
        }
    }
}
