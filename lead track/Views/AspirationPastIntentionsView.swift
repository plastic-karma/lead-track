import SwiftData
import SwiftUI

/// Behind the detail's "Past intentions" disclosure row: the narrative
/// history, newest week first — a story, not a statistic. Rows are deletable
/// (the data is the user's) but never editable — closures are final. No
/// aggregates and no completion rate: the outcome word, or the final
/// accumulation standing as fact.
struct AspirationPastIntentionsView: View {
    @Environment(\.modelContext) private var modelContext
    let aspiration: Aspiration

    var body: some View {
        List {
            ForEach(pastIntentions) { intention in
                historyRow(intention)
            }
            .onDelete(perform: deleteIntentions)
        }
        .navigationTitle("Past Intentions")
        .navigationBarTitleDisplayMode(.inline)
        .overlay { emptyState }
    }

    /// The intentions no longer live in the current week, newest week first.
    /// Static and shared with the detail's disclosure row, so the week count
    /// there and the list here never disagree.
    static func pastIntentions(of aspiration: Aspiration) -> [Intention] {
        aspiration.intentions
            .filter { !($0.isOpen && $0.isInCurrentWeek()) }
            .sorted {
                ($0.weekStart, $0.createdAt) > ($1.weekStart, $1.createdAt)
            }
    }
}

// MARK: - Rows

extension AspirationPastIntentionsView {
    private var pastIntentions: [Intention] {
        Self.pastIntentions(of: aspiration)
    }

    /// Shown only after the last row is deleted right here — the detail
    /// hides its disclosure row entirely when no history exists.
    @ViewBuilder
    private var emptyState: some View {
        if pastIntentions.isEmpty {
            ContentUnavailableView("No Past Intentions", systemImage: "leaf")
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

    private func deleteIntentions(_ offsets: IndexSet) {
        let targets = offsets.map { pastIntentions[$0] }
        withAnimation {
            for intention in targets {
                NotificationService.cancelQuestion(for: intention)
                modelContext.delete(intention)
            }
        }
    }
}
