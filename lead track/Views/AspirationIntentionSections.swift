import SwiftData
import SwiftUI

/// The intention blocks of the aspiration detail: the current week's
/// commitments (same row anatomy as Today) and, at the bottom, the narrative
/// history — a story, not a statistic. No aggregates, no charts, no counts of
/// dones, ever.
extension AspirationDetailView {
    /// "This week", between the why and the effort: the open commitments and
    /// the second doorway (after the review) for setting one.
    @ViewBuilder
    var thisWeekSection: some View {
        Section("This Week") {
            ForEach(currentWeekIntentions) { intention in
                IntentionRowView(intention: intention)
            }
            Button { showingSetIntention = true } label: {
                Label("Set an intention", systemImage: "plus.circle")
            }
        }
    }

    /// Past intentions, newest week first. Rows are deletable (the data is
    /// the user's) but never editable — closures are final.
    @ViewBuilder
    var pastIntentionsSection: some View {
        if !pastIntentions.isEmpty {
            Section("Past Intentions") {
                ForEach(pastIntentions) { intention in
                    historyRow(intention)
                }
                .onDelete(perform: deletePastIntentions)
            }
        }
    }
}

// MARK: - Rows

extension AspirationDetailView {
    private var currentWeekIntentions: [Intention] {
        aspiration.intentions
            .filter { $0.isOpen && $0.isInCurrentWeek() }
            .sorted { $0.createdAt < $1.createdAt }
    }

    private var pastIntentions: [Intention] {
        aspiration.intentions
            .filter { !($0.isOpen && $0.isInCurrentWeek()) }
            .sorted {
                ($0.weekStart, $0.createdAt) > ($1.weekStart, $1.createdAt)
            }
    }

    private func historyRow(_ intention: Intention) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Week of \(intention.weekStart.formatted(.dateTime.month(.abbreviated).day()))")
                .font(.caption2)
                .foregroundStyle(.secondary)
            HStack {
                Text(intention.title)
                    .font(.subheadline)
                Spacer()
                Text(historyDetail(intention))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    /// The narrative ending: the outcome word, or the final accumulation
    /// standing as fact, or "unclosed" — never a judgment.
    private func historyDetail(_ intention: Intention) -> String {
        if let progress = IntentionProgress.compute(for: intention) {
            return progress.text
        }
        if intention.isSourceRemoved {
            return "source removed"
        }
        return intention.outcome?.label ?? "unclosed"
    }

    private func deletePastIntentions(_ offsets: IndexSet) {
        let targets = offsets.map { pastIntentions[$0] }
        withAnimation {
            for intention in targets {
                modelContext.delete(intention)
            }
        }
    }
}
