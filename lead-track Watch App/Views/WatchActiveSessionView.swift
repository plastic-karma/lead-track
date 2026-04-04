import SwiftData
import SwiftUI

struct WatchActiveSessionView: View {
    @Environment(\.modelContext) private var modelContext
    let metric: Metric
    @Query private var sessions: [Session]

    init(metric: Metric) {
        self.metric = metric
        let id = metric.persistentModelID
        _sessions = Query(
            filter: #Predicate<Session> {
                $0.metric?.persistentModelID == id
                    && $0.endedAt == nil
            },
            sort: \.startedAt
        )
    }

    private var activeSession: Session? {
        sessions.first
    }

    var body: some View {
        VStack(spacing: 16) {
            Text(metric.name)
                .font(.headline)
            if let session = activeSession {
                runningView(session)
            } else {
                stoppedView
            }
        }
        .navigationTitle(metric.name)
    }

    private func runningView(_ session: Session) -> some View {
        VStack(spacing: 12) {
            Text(session.startedAt, style: .timer)
                .monospacedDigit()
                .font(.title)
                .foregroundStyle(.orange)
            Button("Stop", role: .destructive) {
                SessionService.stopSession(session)
            }
        }
    }

    private var stoppedView: some View {
        Button {
            startTimer()
        } label: {
            Label("Start", systemImage: "play.fill")
        }
        .tint(.green)
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
        withAnimation {
            SessionService.stopSession(for: metric)
        }
    }
}
