import SwiftUI

/// The oversubscription check-in block of the weekly review: one calm card that
/// asks whether the week is carrying more daily goals than it can hold, when
/// they rarely all land together across the last three weeks. A reflection, not
/// a task — no CTA, no count of debt — so it sits in the why-zone above the
/// per-goal season decisions. Live review only; when there is nothing to raise
/// the block is simply absent (see `OversubscriptionInsight`).
extension WeeklyReviewView {
    /// The header's close button sends this slide away until next week (a
    /// sideways swipe pages the deck now); `WeeklyCheckInDismissal`
    /// remembers the week, so it returns on its own once the week rolls
    /// over.
    @ViewBuilder
    func oversubscriptionSection(_ review: WeeklyReview) -> some View {
        if let checkIn = review.oversubscription,
           !WeeklyCheckInDismissal.isDismissed(storedWeekStart: dismissedOversubscriptionWeek)
        {
            oversubscriptionCard(checkIn)
        }
    }

    private func oversubscriptionCard(_ checkIn: OversubscriptionInsight.CheckIn) -> some View {
        VStack(spacing: 16) {
            dismissibleSectionHeader("Check-In", dismiss: dismissOversubscription)
            VStack(alignment: .leading, spacing: 8) {
                Label(checkIn.headline, systemImage: checkIn.symbol)
                    .font(.subheadline.weight(.medium))
                Text(checkIn.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardSurface()
        }
        .padding(.horizontal)
    }

    /// Hides the oversubscription check-in for the rest of the calendar week;
    /// it returns on its own next week (see `WeeklyCheckInDismissal`).
    private func dismissOversubscription() {
        withAnimation(.easeOut(duration: 0.2)) {
            dismissedOversubscriptionWeek = WeeklyCheckInDismissal.marker(for: .now)
        }
    }
}
