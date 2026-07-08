import SwiftUI

/// The oversubscription check-in block of the weekly review: one calm card that
/// asks whether the week is carrying more daily goals than it can hold, when
/// they rarely all land together across the last three weeks. A reflection, not
/// a task — no CTA, no count of debt — so it sits in the why-zone above the
/// per-goal season decisions. Live review only; when there is nothing to raise
/// the block is simply absent (see `OversubscriptionInsight`).
extension WeeklyReviewView {
    @ViewBuilder
    func oversubscriptionSection(_ review: WeeklyReview) -> some View {
        if let checkIn = review.oversubscription {
            VStack(spacing: 16) {
                sectionBreak("Check-In")
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
    }
}
