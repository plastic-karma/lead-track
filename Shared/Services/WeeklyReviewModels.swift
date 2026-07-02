import Foundation

// MARK: - Review Models

extension WeeklyReview {
    /// How a metric's week compares to the week before it.
    enum WeekChange: Equatable {
        case up(ratio: Double)
        case down(ratio: Double)
        case flat
        /// Nothing was logged the week before, so there is no comparison.
        case noBaseline
    }

    /// One metric's week, ready to render as a review page.
    struct MetricWeek: Identifiable {
        let id: String
        let name: String
        let icon: String
        let colorName: String?
        let measurementType: MeasurementType
        let unit: String?
        /// Sum of tracking values over the period.
        let total: Double
        let change: WeekChange
        let sessionCount: Int
        let activeDays: Int
        /// Per-day tracking-value totals, oldest first, zero-filled.
        let dailySeries: [Double]
        let streak: Int
        /// Days the daily goal was met, nil when no goal is set.
        let goalDaysHit: Int?
        let insights: [Insight]
    }

    /// A metric with no completed sessions in the period.
    struct QuietMetric: Identifiable {
        let id: String
        let name: String
        let icon: String
    }

    /// One aspiration's week — the review's lens. It leads with the lifetime
    /// effort poured in (continuity, never a target), shows what landed this
    /// week, and carries the week's intentions so the card is the one place
    /// the aspiration's week lives. Tapping through opens the day-by-day
    /// distribution.
    struct AspirationWeek: Identifiable {
        /// The aspiration's stable identity, so the pager and its scroll
        /// position survive reorders and deletions.
        let id: String
        let title: String
        let icon: String
        let colorName: String?
        /// The only-grows headline ("142h 30m · 1,240 pages"), window-agnostic.
        let lifetimeSummary: String
        /// This week's effort, one entry per unit ("2h 10m · 45 pages").
        let totals: [UnitTotal]
        let sessionCount: Int
        let activeDays: Int
        /// Sessions per day across the aspiration, oldest first, zero-filled.
        let dailySeries: [Double]
        /// The current week's open intentions, empty when browsing earlier
        /// weeks — intention machinery lives only on the live review.
        let intentions: [IntentionLine]
    }

    /// One open intention rendered inside its aspiration's card: the
    /// commitment and its factual accumulation, nothing more.
    struct IntentionLine: Identifiable {
        /// The intention's stable identity.
        let id: String
        let title: String
        /// "2 of 3" / "4 of 7 days"; nil for reflective intentions, which
        /// deliberately carry no progress value.
        let progressText: String?
    }

    /// An aspiration with no logged effort in the period. It still shows its
    /// lifetime total, so a quiet week reads as continuity, not failure.
    struct QuietAspiration: Identifiable {
        let id: String
        let title: String
        let icon: String
        let lifetimeSummary: String
    }
}
