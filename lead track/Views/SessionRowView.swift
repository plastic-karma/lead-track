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
                Text(DurationFormatter.format(session.duration))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
    }
}
