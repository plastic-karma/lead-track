import SwiftData
import SwiftUI

/// The "This week" card of the aspiration detail: the current week's
/// commitments, each naming the principle it serves (the row's identity
/// carrier here — the aspiration is already the page, so no glyph), and the
/// quiet doorway to set another. No aggregates, no charts, no counts of
/// dones, ever; the narrative history waits behind the detail's "Past
/// intentions" disclosure row (see `AspirationPastIntentionsView`), and the
/// weekly alignment pulse lives at the weekly review.
struct AspirationIntentionsCard: View {
    let aspiration: Aspiration
    @State private var isExpanded = true
    @State private var showingSetIntention = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            AspirationCardHeader(title: "This week", isExpanded: $isExpanded)
            if isExpanded {
                if currentWeekIntentions.isEmpty {
                    Text("No open intentions this week.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 12)
                }
                ForEach(currentWeekIntentions) { intention in
                    IntentionRowView(intention: intention, showsPrinciple: true)
                        .padding(.vertical, 11)
                    Divider()
                }
                if !aspiration.isArchived {
                    AspirationPlusRow(title: "Set an intention", tint: aspiration.displayColor) {
                        showingSetIntention = true
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, isExpanded ? 0 : 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { Theme.cardShape() }
        .sheet(isPresented: $showingSetIntention) {
            IntentionFormView(aspiration: aspiration)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private var currentWeekIntentions: [Intention] {
        aspiration.intentions
            .filter { $0.isOpen && $0.isInCurrentWeek() }
            .sorted { $0.createdAt < $1.createdAt }
    }
}
