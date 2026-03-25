import SwiftData
import SwiftUI

struct WatchActiveSessionView: View {
    @Environment(\.modelContext) private var modelContext
    let metric: Metric

    private var activeSession: Session? {
        metric.sessions.first { $0.isRunning }
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
                stopTimer()
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
        try? SessionService.startSession(
            for: metric,
            in: modelContext
        )
    }

    private func stopTimer() {
        try? SessionService.stopSession(
            for: metric,
            in: modelContext
        )
    }
}
