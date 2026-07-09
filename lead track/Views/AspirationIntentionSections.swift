import SwiftData
import SwiftUI

/// The "This week" card of the aspiration detail: the current week's
/// commitments, each naming the principle it serves (the row's identity
/// carrier here — the aspiration is already the page, so no glyph), and the
/// quiet doorway to set another. No aggregates, no charts, no counts of
/// dones, ever; the narrative history waits behind the detail's "Past
/// intentions" disclosure row (see `AspirationPastIntentionsView`), and the
/// weekly alignment pulse lives at the weekly review.
extension AspirationDetailView {
    var thisWeekCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            collapsibleCardHeader("This week", isExpanded: $thisWeekExpanded)
            if thisWeekExpanded {
                ForEach(currentWeekIntentions) { intention in
                    IntentionRowView(intention: intention, showsPrinciple: true)
                        .padding(.vertical, 11)
                    cardDivider()
                }
                plusRow("Set an intention") { showingSetIntention = true }
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
