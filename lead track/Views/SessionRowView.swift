import SwiftUI

struct SessionRowView: View {
    let session: Session
    var showsDate = true

    var body: some View {
        HStack {
            timestamp
            Spacer()
            valueLabel
        }
    }

    /// Day-grouped lists carry the date in their section header, so rows
    /// only repeat the time of day.
    @ViewBuilder
    private var timestamp: some View {
        if showsDate {
            VStack(alignment: .leading) {
                Text(session.startedAt, style: .date)
                    .font(.subheadline)
                Text(session.startedAt, style: .time)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } else {
            Text(session.startedAt, style: .time)
                .font(.subheadline)
        }
    }

    @ViewBuilder
    private var valueLabel: some View {
        if session.isRunning {
            TimerDisplay(startedAt: session.startedAt)
        } else if let count = session.value {
            Text(countText(count))
                .numeralStyle(.stat)
                .foregroundStyle(.secondary)
        } else {
            Text(DurationFormatter.format(session.duration))
                .numeralStyle(.stat)
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
