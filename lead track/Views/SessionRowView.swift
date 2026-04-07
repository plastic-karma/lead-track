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
            valueLabel
        }
    }

    @ViewBuilder
    private var valueLabel: some View {
        if session.isRunning {
            TimerDisplay(startedAt: session.startedAt)
        } else if let count = session.value {
            Text(countText(count))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        } else {
            Text(DurationFormatter.format(session.duration))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }

    private func countText(_ count: Double) -> String {
        let unit = session.metric?.unit
        return ValueFormatter.format(
            count, type: .count, unit: unit
        )
    }
}
