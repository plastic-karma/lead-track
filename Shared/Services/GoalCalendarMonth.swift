import Foundation

/// The single judged series a calendar can center on: the goal-bearing
/// metric, the sessions that count toward it, and the day judgment begins —
/// a project passes its own slice and start, so its calendar never blames
/// days before it existed.
struct GoalCalendarSeries {
    let metric: Metric
    let sessions: [Session]
    let since: Date
}

/// One rendered month of the goal calendar, computed once per screen pass:
/// the week grid plus per-day judgments — a series month judges one metric
/// (or a project's slice of one), a tallied month counts every listed
/// metric's goals — and the strings the screen prints in cells and under
/// the grid.
struct GoalCalendarMonth {
    let weeks: [[Date?]]
    let series: GoalCalendarSeries?
    private let outcomes: [Date: GoalCalendar.DayOutcome]
    private let tallies: [Date: GoalCalendar.DayTally]

    init(
        series: GoalCalendarSeries?,
        talliedMetrics: [Metric],
        monthOf date: Date,
        now: Date = .now,
        calendar: Calendar = .current
    ) {
        weeks = GoalCalendar.weeks(inMonthOf: date, calendar: calendar)
        self.series = series
        if let series {
            outcomes = GoalCalendar.outcomes(
                for: series.metric,
                sessions: series.sessions,
                monthOf: date,
                since: series.since,
                now: now,
                calendar: calendar
            )
            tallies = [:]
        } else {
            outcomes = [:]
            tallies = GoalCalendar.tallies(
                for: talliedMetrics, monthOf: date, now: now, calendar: calendar
            )
        }
    }
}

// MARK: - Cell readings

extension GoalCalendarMonth {
    /// Reached-over-applicable for the day: 1 fills the disc, 0 draws the
    /// unmet ring, in-between fills faintly. nil = no goal applied.
    func fraction(on day: Date) -> Double? {
        if let outcome = outcomes[day] {
            return Self.seriesFraction(of: outcome.verdict)
        }
        guard let tally = tallies[day], tally.total > 0 else { return nil }
        return Double(tally.met) / Double(tally.total)
    }

    private static func seriesFraction(of verdict: GoalCalendar.Verdict) -> Double? {
        switch verdict {
        case .met: 1
        case .missed: 0
        case .rest, .free: nil
        }
    }

    /// The small figure under a day number: the day's compact value on a
    /// quantity series ("1h05", "12"), met-over-total on a tallied month
    /// ("2/3"), nil where there is nothing to print. Binary series let the
    /// disc speak alone.
    func cellDetail(on day: Date) -> String? {
        if series != nil {
            return seriesDetail(on: day)
        }
        guard let tally = tallies[day], tally.total > 0 else { return nil }
        return "\(tally.met)/\(tally.total)"
    }

    private func seriesDetail(on day: Date) -> String? {
        guard let series,
              let outcome = outcomes[day],
              outcome.value > 0,
              series.metric.measurementType.tracksQuantity
        else { return nil }
        if series.metric.measurementType == .duration {
            return DurationFormatter.compact(outcome.value)
        }
        return ValueFormatter.formatShort(outcome.value, type: .count)
    }
}

// MARK: - Summary line

extension GoalCalendarMonth {
    /// The line under the grid: a series month's "Goal met on 8 of 20 days
    /// · 12h 40m in all", a tallied month's "42 of 96 held this month."
    var summaryText: String {
        if let series {
            return Self.seriesSummaryText(GoalCalendar.summary(of: outcomes), series: series)
        }
        let summary = GoalCalendar.summary(of: tallies)
        guard summary.hasGoals else { return "No daily goals this month." }
        return "\(summary.met) of \(summary.total) held this month."
    }

    private static func seriesSummaryText(
        _ summary: GoalCalendar.SeriesSummary,
        series: GoalCalendarSeries
    ) -> String {
        var parts: [String] = []
        if summary.goalDays > 0 {
            parts.append("Goal met on \(summary.metDays) of \(ValueFormatter.days(summary.goalDays))")
        } else {
            parts.append("No daily goal to judge")
        }
        if summary.totalValue > 0, series.metric.measurementType.tracksQuantity {
            let total = ValueFormatter.format(
                summary.totalValue,
                type: series.metric.measurementType,
                unit: series.metric.unit
            )
            parts.append("\(total) in all")
        }
        return parts.joined(separator: " · ")
    }
}

// MARK: - Month summaries

extension GoalCalendar {
    /// A month of one series folded to its headline: goal days met, goal
    /// days judged, and the month's whole logged value (rest and free days
    /// included — effort counts even where no goal applied).
    struct SeriesSummary: Equatable {
        let metDays: Int
        let goalDays: Int
        let totalValue: Double
    }

    /// Folds a month of series outcomes to its headline figures.
    static func summary(of outcomes: [Date: DayOutcome]) -> SeriesSummary {
        var metDays = 0
        var goalDays = 0
        var totalValue = 0.0
        for outcome in outcomes.values {
            totalValue += outcome.value
            switch outcome.verdict {
            case .met:
                metDays += 1
                goalDays += 1
            case .missed:
                goalDays += 1
            case .rest, .free:
                break
            }
        }
        return SeriesSummary(metDays: metDays, goalDays: goalDays, totalValue: totalValue)
    }

    /// Folds a month of tallies to reached-over-applicable, in the app's one
    /// met/total vocabulary.
    static func summary(of tallies: [Date: DayTally]) -> GoalSummary {
        GoalSummary(
            met: tallies.values.reduce(0) { $0 + $1.met },
            total: tallies.values.reduce(0) { $0 + $1.total }
        )
    }
}
