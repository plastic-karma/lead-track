import SwiftData
import SwiftUI

struct ProjectDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let project: Project
    @Query private var sessions: [Session]
    @State private var showingDetailedStats = false
    @State private var showingCountEntry = false

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

    var body: some View {
        List {
            timerSection
            StatisticsView(
                sessions: sessions,
                measurementType: project.metric?.measurementType ?? .duration,
                unit: project.metric?.unit,
                dailyGoal: nil,
                weeklyGoal: nil,
                showingDetailedStats: $showingDetailedStats
            )
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
                weeklyGoal: nil
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

    private var statusSection: some View {
        Section {
            if project.status == .active {
                Button("Mark as Finished") {
                    finishProject()
                }
            } else {
                Button("Reopen Project") {
                    reopenProject()
                }
            }
        }
    }

    private var sessionsSection: some View {
        Section("Sessions") {
            ForEach(completedSessions) { session in
                SessionRowView(session: session)
            }
            .onDelete(perform: deleteSessions)
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

    private func stopTimer() {
        guard let metric = project.metric else { return }
        SessionService.stopSession(for: metric)
    }

    private func finishProject() {
        project.status = .finished
        project.finishedAt = .now
    }

    private func reopenProject() {
        project.status = .active
        project.finishedAt = nil
    }

    private func deleteProject() {
        modelContext.delete(project)
        dismiss()
    }

    private func deleteSessions(_ offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(completedSessions[index])
            }
        }
    }
}
