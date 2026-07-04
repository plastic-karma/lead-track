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

    /// One aspiration's week — the review's lens. It carries only what landed
    /// in the reviewed seven days plus the week's intentions, so the card is
    /// the one place the aspiration's week lives; lifetime totals stay on the
    /// aspiration's own screen. Tapping through opens the day-by-day
    /// distribution.
    struct AspirationWeek: Identifiable {
        /// The aspiration's stable identity, so the pager and its scroll
        /// position survive reorders and deletions.
        let id: String
        let title: String
        let icon: String
        let colorName: String?
        /// This week's effort, one entry per unit ("2h 10m · 45 pages").
        let totals: [UnitTotal]
        let sessionCount: Int
        let activeDays: Int
        /// Sessions per day across the aspiration, oldest first, zero-filled.
        let dailySeries: [Double]
        /// The current week's open intentions, empty when browsing earlier
        /// weeks — intention machinery lives only on the live review.
        let intentions: [IntentionLine]
        /// Whether the card offers this week's alignment pulse — true only on
        /// the live week when the aspiration hasn't checked in yet. Skipping
        /// is structurally invisible: no badge, no queue, no staging change.
        let offersCheckIn: Bool
        /// The narrowing observation (see `MeasureHealth`), live review only;
        /// nil is the norm.
        let narrowing: MeasureHealth.Narrowing?
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

    /// An aspiration with no logged effort in the period. It keeps its seat
    /// on the review by name alone — its totals live on its own screen.
    struct QuietAspiration: Identifiable {
        let id: String
        let title: String
        let icon: String
    }
}
