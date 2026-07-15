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
            TimerDisplay(
                startedAt: session.startedAt,
                tint: session.metric?.displayColor ?? .accentColor
            )
        } else if session.metric?.measurementType == .binary {
            Text(session.displayValue(unit: nil))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        } else {
            Text(session.displayValue(unit: session.metric?.unit))
                .numeralStyle(.stat)
                .foregroundStyle(.secondary)
        }
    }
}
