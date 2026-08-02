import Foundation

/// The weekly review's set-an-intention asks: metrics whose daily goal went
/// unmet on more than `missThreshold` of the last week's goal days, each
/// inviting a week-scoped intention under an aspiration the metric serves.
/// The ask is an opening, not a verdict — the row states the week as fact
/// and offers the intention form; setting one (or the week rolling over)
/// quiets it.
///
/// Judged days follow the `OversubscriptionInsight` conventions: only the
/// completed days before today count (today is still in progress and can
/// never read as a miss), rest days drop out per metric, and each metric
/// weighs in only from its first live day (creation, pulled back to imported
/// history), so a goal added mid-week never turns earlier days into misses.
/// Unlike oversubscription there is no worked-on filter — a no-show on a
/// goal day is exactly the miss the ask is about.
///
/// Two structural quiets, both doctrine rather than threshold: a metric
/// serving no aspiration is skipped (an intention nests under a why —
/// `Intention.make` refuses standalone ones — so the ask is only made where
/// it can be answered), and a metric already carrying an open intention this
/// calendar week is skipped (asked and answered; released mid-week, the ask
/// stands again). Pure Foundation math, unit-tested on Linux like the rest
/// of the review assembly.
enum GoalShortfall {
    /// Completed days looked back over — the last week.
    static let windowDays = 7
    /// Unmet goal days beyond this raise the ask — "not reached my daily
    /// goal more than 3 times in the last week", as the request was phrased.
    static let missThreshold = 3

    /// One metric's ask, carrying what its review row shows. An empty list
    /// from `asks(for:)` means nothing to ask — the review shows no section.
    struct Ask: Identifiable, Equatable {
        /// The metric's stable identity, mapped back to the model when the
        /// row routes into the intention form.
        let id: String
        let name: String
        let icon: String
        let colorName: String?
        /// Days judged: completed days the goal applied and the metric lived.
        let goalDays: Int
        /// Of those, the days the goal went unmet.
        let missedDays: Int
    }

    /// The asks for the live review, in the metrics' incoming order.
    static func asks(
        for metrics: [Metric],
        aspirations: [Aspiration] = [],
        intentions: [Intention] = [],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [Ask] {
        let served = servedMetrics(among: aspirations)
        let committed = committedMetrics(among: intentions, now: now, calendar: calendar)
        return metrics
            .filter { GoalSummary.hasDailyTarget($0) }
            .filter { served.contains(ObjectIdentifier($0)) && !committed.contains(ObjectIdentifier($0)) }
            .compactMap { ask(for: $0, now: now, calendar: calendar) }
    }
}

// MARK: - Copy

extension GoalShortfall.Ask {
    /// Judged days on which the goal landed.
    var metDays: Int {
        goalDays - missedDays
    }

    /// The week as fact — no judgment copy; the invitation to set an
    /// intention belongs to the section around the row.
    var detail: String {
        "Met on \(metDays) of \(goalDays) goal days this past week."
    }
}

// MARK: - Selection

private extension GoalShortfall {
    /// Metrics attached to at least one aspiration — the only place an
    /// intention can nest — read through the forward `Aspiration.metrics`
    /// relationship (the plain back-array on `Metric` never populates; see
    /// `GoalSeason.reviews`).
    static func servedMetrics(among aspirations: [Aspiration]) -> Set<ObjectIdentifier> {
        Set(aspirations.flatMap { $0.metrics.map(ObjectIdentifier.init) })
    }

    /// Metrics already carrying an open intention in the calendar week
    /// containing `now`. The derived link is the tie — a reflective or
    /// counted commitment made elsewhere never silences an ask.
    static func committedMetrics(
        among intentions: [Intention],
        now: Date,
        calendar: Calendar
    ) -> Set<ObjectIdentifier> {
        let current = intentions.filter {
            $0.isOpen && Intention.week(starting: $0.weekStart, contains: now, calendar: calendar)
        }
        return Set(current.compactMap { $0.metric.map(ObjectIdentifier.init) })
    }

    /// One metric's ask, or nil while its misses stay within the threshold.
    static func ask(for metric: Metric, now: Date, calendar: Calendar) -> Ask? {
        let days = judgedDays(of: metric, now: now, calendar: calendar)
        let missed = days.count { !GoalDayOutcome.isMet(metric, on: $0, calendar: calendar) }
        guard missed > missThreshold else { return nil }
        return Ask(
            id: metric.stableIdentity,
            name: metric.name,
            icon: metric.displayIcon,
            colorName: metric.colorName,
            goalDays: days.count,
            missedDays: missed
        )
    }

    /// The completed days of the window the metric can be judged on: its
    /// goal days (rest days out) from its first live day.
    static func judgedDays(of metric: Metric, now: Date, calendar: Calendar) -> [Date] {
        let today = calendar.startOfDay(for: now)
        let from = GoalDayOutcome.firstLiveDay(of: metric, calendar: calendar)
        return (1 ... windowDays)
            .compactMap { calendar.date(byAdding: .day, value: -$0, to: today) }
            .filter { $0 >= from && metric.isGoalDay(on: $0, calendar: calendar) }
    }
}
