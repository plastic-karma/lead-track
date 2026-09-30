import SwiftData
import SwiftUI

/// The full session history behind the History fold's "Show all": every
/// completed direct session (project sessions live on their project's
/// screen), day-grouped, with the swipe actions the fold's preview rows
/// trade away for compactness.
struct MetricSessionsListView: View {
    let metric: Metric
    @Query private var sessions: [Session]
    @State private var sessionToMove: Session?

    init(metric: Metric) {
        self.metric = metric
        let id = metric.persistentModelID
        _sessions = Query(
            filter: #Predicate<Session> {
                $0.metric?.persistentModelID == id
            },
            sort: \.startedAt,
            order: .reverse
        )
    }

    private var directSessions: [Session] {
        sessions.filter { $0.project == nil && !$0.isRunning }
    }

    var body: some View {
        List {
            ForEach(SessionDayGrouping.group(directSessions)) { group in
                MetricSessionDaySection(
                    group: group, canMove: !metric.projects.isEmpty, sessionToMove: $sessionToMove
                )
            }
        }
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $sessionToMove) { session in
            MoveSessionView(session: session)
        }
    }
}

// MARK: - Sections

private struct MetricSessionDaySection: View {
    @Environment(\.modelContext) private var modelContext
    let group: SessionDayGroup
    let canMove: Bool
    @Binding var sessionToMove: Session?

    var body: some View {
        Section(SessionDayGrouping.label(for: group.day)) {
            ForEach(group.sessions) { session in
                sessionRow(session)
            }
            .onDelete { offsets in
                deleteSessions(offsets, in: group)
            }
        }
    }

    private func sessionRow(_ session: Session) -> some View {
        SessionRowView(session: session, showsDate: false)
            .swipeActions(edge: .leading) {
                if canMove {
                    Button { sessionToMove = session } label: {
                        Label("Move", systemImage: "folder")
                    }
                    .tint(.blue)
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
