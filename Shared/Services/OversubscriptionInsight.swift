import Foundation

/// The weekly review's oversubscription check-in: when the daily goals rarely
/// all land together across the last three weeks, the measure may be carrying
/// more daily commitments than the week can hold. This is a cross-metric read
/// by nature — a single goal missed is just a miss, but many goals that never
/// come together on the same day is a load problem — so it lives at the review
/// level beside the goal seasons, not inside one metric's own insight page.
///
/// A day only counts when the goals were actually worked on (at least one
/// active daily goal logged something), so days before the user began, full
/// off days, and vacations never read as misses; a miss is a day you showed up
/// for the goals but couldn't complete them all. Rest days (excluded weekdays)
/// drop out per metric via `Metric.isGoalDay`. Pure Foundation math, so it is
/// unit-tested on Linux like the rest of the review assembly.
enum OversubscriptionInsight {
    /// Days looked back over — three weeks, the window the user asked about.
    static let windowDays = 21
    /// The share of active days on which not every daily goal was met, above
    /// which the check-in surfaces — phrased as the request was: "not reaching
    /// all daily goals for more than 20% of the time".
    static let missRateThreshold = 0.20
    /// Oversubscription is a juggling-too-many story; with a single daily goal
    /// a miss is just a miss, so the check-in needs at least this many active
    /// daily goals before it has anything to say.
    static let minGoalCount = 2
    /// A week's worth of active days at minimum, so the rate reflects a pattern
    /// rather than a couple of stray days.
    static let minActiveDays = 7

    /// The surfaced check-in, carrying the figures its copy needs. `nil` from
    /// `checkIn(for:)` means nothing to say — the review shows no section.
    struct CheckIn: Equatable {
        /// Active daily goals currently carried.
        let goalCount: Int
        /// Active days on which at least one daily goal went unmet.
        let missedDays: Int
        /// Active days weighed in the window (goals were worked on).
        let activeDays: Int

        /// Share of active days that fell short of all the goals.
        var missRate: Double {
            activeDays > 0 ? Double(missedDays) / Double(activeDays) : 0
        }

        /// Active days every daily goal came together.
        var allTogetherDays: Int {
            activeDays - missedDays
        }
    }

    /// The check-in for the live review, or `nil` when the goals mostly land,
    /// there are too few to juggle, or there isn't enough recent activity to
    /// read a pattern.
    static func checkIn(
        for metrics: [Metric],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> CheckIn? {
        let goalMetrics = metrics.filter(GoalSummary.hasDailyTarget)
        guard goalMetrics.count >= minGoalCount else { return nil }
        let counts = tally(goalMetrics, now: now, calendar: calendar)
        guard counts.active >= minActiveDays else { return nil }
        let checkIn = CheckIn(
            goalCount: goalMetrics.count,
            missedDays: counts.missed,
            activeDays: counts.active
        )
        guard checkIn.missRate > missRateThreshold else { return nil }
        return checkIn
    }
}

// MARK: - Copy

extension OversubscriptionInsight.CheckIn {
    var symbol: String {
        "tray.full"
    }

    var headline: String {
        "Maybe oversubscribed?"
    }

    /// Ends in a question by design: the check-in questions the load, never the
    /// user (the measure-health voice).
    var detail: String {
        "Your \(goalCount) daily goals all landed together on only "
            + "\(allTogetherDays) of \(activeDays) active days these past three "
            + "weeks. Would carrying fewer at once serve the why better than "
            + "reaching for them all?"
    }
}

// MARK: - Tally

private extension OversubscriptionInsight {
    /// Walks the completed days before today — today is still in progress and
    /// would read as a false miss — keeping the days the goals were worked on,
    /// then counts them and, among them, the days one fell short.
    static func tally(
        _ metrics: [Metric],
        now: Date,
        calendar: Calendar
    ) -> (active: Int, missed: Int) {
        let today = calendar.startOfDay(for: now)
        let days = (1 ... windowDays)
            .compactMap { calendar.date(byAdding: .day, value: -$0, to: today) }
            .map { outcome(of: metrics, on: $0, calendar: calendar) }
            .filter { $0.engaged }
        return (days.count, days.count { $0.fellShort })
    }

    /// Whether any applicable goal was worked on that day, and whether any went
    /// unmet — weighed only over metrics whose goal applies (rest days drop out).
    static func outcome(
        of metrics: [Metric],
        on day: Date,
        calendar: Calendar
    ) -> (engaged: Bool, fellShort: Bool) {
        let totals = metrics
            .filter { $0.isGoalDay(on: day, calendar: calendar) }
            .map { (metric: $0, total: dayTotal(of: $0, on: day, calendar: calendar)) }
        let engaged = totals.contains { $0.total > 0 }
        let fellShort = totals.contains { !isMet($0.metric, dayTotal: $0.total) }
        return (engaged, fellShort)
    }

    static func isMet(_ metric: Metric, dayTotal: Double) -> Bool {
        if metric.measurementType == .binary { return dayTotal > 0 }
        return dayTotal >= (metric.dailyGoal ?? 0)
    }

    static func dayTotal(
        of metric: Metric,
        on day: Date,
        calendar: Calendar
    ) -> Double {
        metric.sessions
            .filter { !$0.isRunning && calendar.isDate($0.startedAt, inSameDayAs: day) }
            .reduce(0) { $0 + $1.trackingValue }
    }
}
