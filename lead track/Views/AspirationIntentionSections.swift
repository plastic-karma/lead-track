import SwiftData
import SwiftUI

/// The "This week" card of the aspiration detail: the current week's
/// commitments (same row anatomy as Today), the quiet doorway to set another,
/// and — past a hairline — the pulse block (see `AspirationPulseSection`).
/// No aggregates, no charts, no counts of dones, ever; the narrative history
/// waits behind the detail's "Past intentions" disclosure row (see
/// `AspirationPastIntentionsView`).
extension AspirationDetailView {
    var thisWeekCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            collapsibleCardHeader("This week", isExpanded: $thisWeekExpanded)
            if thisWeekExpanded {
                ForEach(currentWeekIntentions) { intention in
                    IntentionRowView(intention: intention)
                        .padding(.vertical, 11)
                    cardDivider(inset: 36)
                }
                plusRow("Set an intention") { showingSetIntention = true }
                cardDivider()
                pulseBlock
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, thisWeekExpanded ? 0 : 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.cardShape())
    }

    private var currentWeekIntentions: [Intention] {
        aspiration.intentions
            .filter { $0.isOpen && $0.isInCurrentWeek() }
            .sorted { $0.createdAt < $1.createdAt }
    }
}
