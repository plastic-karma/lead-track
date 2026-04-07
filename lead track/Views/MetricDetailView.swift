import SwiftData
import SwiftUI

struct MetricDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let metric: Metric
    @Query private var sessions: [Session]
    @State private var showingProjectForm = false
    @State private var showingDetailedStats = false

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

    var body: some View {
        List {
            timerSection
            StatisticsView(
                sessions: sessions,
                showingDetailedStats: $showingDetailedStats
            )
            if !activeProjects.isEmpty {
                projectsSection("Active Projects", activeProjects)
            }
            if !directSessions.isEmpty {
                directSessionsSection
            }
            if !finishedProjects.isEmpty {
                projectsSection("Finished", finishedProjects)
            }
        }
        .navigationTitle(metric.name)
        .toolbar {
            ToolbarItem {
                Button { showingProjectForm = true } label: {
                    Label("Add Project", systemImage: "folder.badge.plus")
                }
            }
        }
        .sheet(isPresented: $showingProjectForm) {
            ProjectFormView(metric: metric)
        }
        .sheet(isPresented: $showingDetailedStats) {
            DetailedStatisticsView(
                dailyTotals: SessionStatistics.dailyTotals(
                    from: sessions
                )
            )
        }
    }
}

// MARK: - Sections

extension MetricDetailView {
    private var timerSection: some View {
        Section {
            if let session = activeSession {
                ActiveSessionBanner(session: session)
                Button("Stop Timer", role: .destructive) {
                    SessionService.stopSession(session)
                }
            } else {
                Button { startTimer() } label: {
                    Label("Start Timer", systemImage: "play.fill")
                }
            }
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

    private var directSessionsSection: some View {
        Section("Sessions") {
            ForEach(directSessions) { session in
                SessionRowView(session: session)
            }
            .onDelete(perform: deleteDirectSessions)
        }
    }
}

// MARK: - Helpers

extension MetricDetailView {
    private func projectRow(_ project: Project) -> some View {
        HStack {
            Text(project.name)
            Spacer()
            if project.sessions.contains(where: \.isRunning) {
                Image(systemName: "record.circle")
                    .foregroundStyle(.red)
                    .symbolEffect(.pulse)
            }
            Text("\(project.sessions.count) sessions")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func startTimer() {
        withAnimation {
            SessionService.startSession(
                for: metric,
                in: modelContext
            )
        }
    }

    private func stopTimer() {
        SessionService.stopSession(for: metric)
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

    private func deleteDirectSessions(_ offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(directSessions[index])
            }
        }
    }
}
