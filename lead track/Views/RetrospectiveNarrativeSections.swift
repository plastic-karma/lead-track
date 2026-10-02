import SwiftUI

struct RetrospectiveNarrativeSections: View {
    let moments: [Moment]
    let intentions: [Intention]
    let checkIns: [AspirationCheckIn]
    let period: DateInterval

    var body: some View {
        if !moments.isEmpty {
            Section("Moments") {
                ForEach(moments) { RetrospectiveMomentRow(moment: $0) }
            }
        }
        if !intentions.isEmpty {
            Section("Intentions held") {
                ForEach(intentions) { RetrospectiveIntentionRow(intention: $0, period: period) }
            }
        }
        if !checkIns.isEmpty {
            Section("Check-in notes") {
                ForEach(checkIns) { RetrospectiveCheckInRow(checkIn: $0) }
            }
        }
    }
}

private struct RetrospectiveIntentionRow: View {
    let intention: Intention
    let period: DateInterval

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(intention.title)
                .font(IntentionVoice.title)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
            RetrospectiveWeekLabel(date: intention.weekStart, aspirationTitle: intention.aspiration?.title)
            if let principle = intention.principle {
                Text("serves “\(principle.text)”").font(.caption).foregroundStyle(.secondary)
            }
            if let closedAt = intention.closedAt, RetrospectiveReader.contains(closedAt, in: period) {
                Text(
                    "\(intention.outcome?.label ?? "closed") · \(closedAt, format: Date.FormatStyle(date: .abbreviated, time: .omitted))"
                )
                .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct RetrospectiveCheckInRow: View {
    let checkIn: AspirationCheckIn

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(checkIn.note)
                .font(.body)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
            RetrospectiveWeekLabel(date: checkIn.weekStart, aspirationTitle: checkIn.aspiration?.title)
        }
        .padding(.vertical, 4)
    }
}

private struct RetrospectiveWeekLabel: View {
    let date: Date
    let aspirationTitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Week of \(date, format: Date.FormatStyle(date: .abbreviated, time: .omitted))")
            if let aspirationTitle { Text(aspirationTitle) }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}
