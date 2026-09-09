import SwiftUI

struct RetrospectiveNarrativeSections: View {
    let snapshot: RetrospectiveSnapshot
    let period: DateInterval

    var body: some View {
        if !snapshot.moments.isEmpty {
            Section("Moments") {
                ForEach(snapshot.moments) { RetrospectiveMomentRow(moment: $0) }
            }
        }
        if !snapshot.intentions.isEmpty {
            Section("Intentions held") {
                ForEach(snapshot.intentions) { intentionRow($0) }
            }
        }
        if !snapshot.checkIns.isEmpty {
            Section("Check-in notes") {
                ForEach(snapshot.checkIns) { checkInRow($0) }
            }
        }
    }

    private func intentionRow(_ intention: Intention) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(intention.title).font(.subheadline).textSelection(.enabled)
            weekLabel(intention.weekStart, aspiration: intention.aspiration)
            if let principle = intention.principle {
                Text("serves “\(principle.text)”").font(.caption).foregroundStyle(.secondary)
            }
            if let closedAt = intention.closedAt, RetrospectiveReader.contains(closedAt, in: period) {
                Text("\(intention.outcome?.label ?? "closed") · "
                    + closedAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func checkInRow(_ checkIn: AspirationCheckIn) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(checkIn.note).font(.subheadline).textSelection(.enabled)
            weekLabel(checkIn.weekStart, aspiration: checkIn.aspiration)
        }
        .padding(.vertical, 4)
    }

    private func weekLabel(_ date: Date, aspiration: Aspiration?) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Week of \(date.formatted(date: .abbreviated, time: .omitted))")
            if let aspiration { Text(aspiration.title) }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}
