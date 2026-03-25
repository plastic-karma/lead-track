import SwiftUI

struct SessionRowView: View {
    let session: Session

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(session.startedAt, style: .date)
                    .font(.subheadline)
                Text(session.startedAt, style: .time)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if session.isRunning {
                TimerDisplay(startedAt: session.startedAt)
            } else {
                Text(formattedDuration(session.duration))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private func formattedDuration(_ interval: TimeInterval) -> String {
    let hours = Int(interval) / 3600
    let minutes = (Int(interval) % 3600) / 60
    let seconds = Int(interval) % 60
    if hours > 0 {
        return String(format: "%dh %02dm", hours, minutes)
    }
    return String(format: "%dm %02ds", minutes, seconds)
}
