import SwiftData
import SwiftUI

/// The current week's open intentions on Today, sitting just under the header
/// and above the individual metric cards — commitments first, the day's
/// metrics below. Follows the `TodayAspirationsFooter` doctrine: renders
/// nothing when the week has no intentions, so Today stays exactly as it was
/// for non-users.
struct TodayIntentionsSection: View {
    let intentions: [Intention]

    var body: some View {
        let current = intentions.filter { $0.isOpen && $0.isInCurrentWeek() }
        if !current.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                Divider()
                Text("This Week")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .kerning(0.5)
                ForEach(current) { intention in
                    IntentionRowView(intention: intention)
                }
            }
            .padding(.top, 4)
        }
    }
}
