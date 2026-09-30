import SwiftUI

struct SessionRowView: View {
    let session: Session
    var showsDate = true

    var body: some View {
        HStack {
            SessionTimestamp(startedAt: session.startedAt, showsDate: showsDate)
            Spacer()
            SessionValueLabel(session: session)
        }
    }
}

private struct SessionTimestamp: View {
    let startedAt: Date
    let showsDate: Bool

    /// Day-grouped lists carry the date in their section header, so rows
    /// only repeat the time of day.
    var body: some View {
        if showsDate {
            VStack(alignment: .leading) {
                Text(startedAt, style: .date)
                    .font(.subheadline)
                Text(startedAt, style: .time)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } else {
            Text(startedAt, style: .time)
                .font(.subheadline)
        }
    }
}

private struct SessionValueLabel: View {
    let session: Session

    var body: some View {
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
