import Foundation

/// Month math and per-day daily-goal judgment for the calendar screen: one
/// month at a time, every day carrying either a single series' outcome (a
/// metric's day total against its goal, or one project's slice of it) or a
/// tally of how many daily goals were reached across metrics.
///
/// The judgment rule is `GoalSummary`'s, applied to any day instead of today:
/// whether a target exists comes from `DailyTargetRule` (via
/// `GoalSummary.hasDailyTarget`), rest days from `GoalDayRule` (via
/// `Metric.isGoalDay`), and "met" is the same arithmetic `isDailyMet` uses —
/// so the calendar can never disagree with the Today dial.
enum GoalCalendar {
    /// How one day resolved for a judged series.
    enum Verdict {
        /// The daily goal applied and was reached.
        case met
        /// The daily goal applied and was not reached.
        case missed
        /// The goal's schedule rests this weekday.
        case rest
        /// No judgment: no daily target, the day predates the series, or
        /// the day is still ahead.
        case free
    }

    /// One judged day of a series: the day's logged total plus its verdict.
    struct DayOutcome: Equatable {
        let value: Double
        let verdict: Verdict
    }

    /// One day of a tallied calendar: how many daily goals applied and how
    /// many were reached.
    struct DayTally: Equatable {
        let met: Int
        let total: Int
    }
}

// MARK: - Month Grid

extension GoalCalendar {
    /// The first instant of the month containing `date`.
    static func monthStart(
        containing date: Date,
        calendar: Calendar = .current
    ) -> Date {
        calendar.dateInterval(of: .month, for: date)?.start
            ?? calendar.startOfDay(for: date)
    }

    /// The month start `offset` months away from the month containing `date`.
    static func monthStart(
        _ offset: Int,
        from date: Date,
        calendar: Calendar = .current
    ) -> Date {
        let start = monthStart(containing: date, calendar: calendar)
        return calendar.date(byAdding: .month, value: offset, to: start) ?? start
    }

    /// Every day of the month containing `date`, in order.
    static func days(
        inMonthOf date: Date,
        calendar: Calendar = .current
    ) -> [Date] {
        guard let interval = calendar.dateInterval(of: .month, for: date),
              let count = calendar.range(of: .day, in: .month, for: date)?.count
        else { return [] }
        return (0 ..< count).compactMap {
            calendar.date(byAdding: .day, value: $0, to: interval.start)
        }
    }

    /// The month laid out as calendar rows: seven slots per row starting at
    /// the calendar's first weekday, nil where a slot belongs to a
    /// neighboring month.
    static func weeks(
        inMonthOf date: Date,
        calendar: Calendar = .current
    ) -> [[Date?]] {
        let monthDays = days(inMonthOf: date, calendar: calendar)
        guard let first = monthDays.first else { return [] }
        let weekday = calendar.component(.weekday, from: first)
        let leading = (weekday - calendar.firstWeekday + 7) % 7
        var slots = [Date?](repeating: nil, count: leading)
        slots.append(contentsOf: monthDays.map { Optional($0) })
        while slots.count % 7 != 0 {
            slots.append(nil)
        }
        return stride(from: 0, to: slots.count, by: 7).map {
            Array(slots[$0 ..< $0 + 7])
        }
    }

    /// The very-short weekday symbols in grid column order (starting at the
    /// calendar's first weekday), for the header row above the grid.
    static func weekdaySymbols(calendar: Calendar = .current) -> [String] {
        let symbols = calendar.veryShortWeekdaySymbols
        return (0 ..< 7).map { symbols[(calendar.firstWeekday - 1 + $0) % 7] }
    }
}

// MARK: - Series Judgment

extension GoalCalendar {
    /// Judges every day of the month for one series: the goal configuration
    /// comes from `metric`, the logged values from `sessions` — the whole
    /// metric's, or just one project's slice of them when filtered. `since`
    /// overrides where judgment begins (a project passes its own
    /// `trackingStart`, so days before it existed stay free).
    static func outcomes(
        for metric: Metric,
        sessions: [Session],
        monthOf date: Date,
        since: Date? = nil,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [Date: DayOutcome] {
        let totals = dayTotals(of: sessions, calendar: calendar)
        let context = makeContext(for: metric, since: since, now: now, calendar: calendar)
        var result: [Date: DayOutcome] = [:]
        for day in days(inMonthOf: date, calendar: calendar) {
            let value = totals[day] ?? 0
            result[day] = DayOutcome(
                value: value,
                verdict: verdict(value: value, on: day, in: context)
            )
        }
        return result
    }

    /// One series' judgment of a single day — the row behind a tapped cell.
    static func dayOutcome(
        for metric: Metric,
        sessions: [Session],
        on day: Date,
        since: Date? = nil,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> DayOutcome {
        let start = calendar.startOfDay(for: day)
        let value = sessions
            .filter { !$0.isRunning && calendar.isDate($0.startedAt, inSameDayAs: start) }
            .reduce(0) { $0 + $1.trackingValue }
        let context = makeContext(for: metric, since: since, now: now, calendar: calendar)
        return DayOutcome(
            value: value,
            verdict: verdict(value: value, on: start, in: context)
        )
    }

    /// The first day a series is judged from: the metric's creation day, or
    /// its earliest session's day when history was backdated further.
    static func trackingStart(
        of metric: Metric,
        calendar: Calendar = .current
    ) -> Date {
        judgedFrom(metric.createdAt, sessions: metric.sessions, calendar: calendar)
    }

    /// A project slice's judgment start — the same rule anchored to the
    /// project's own life instead of the metric's.
    static func trackingStart(
        of project: Project,
        calendar: Calendar = .current
    ) -> Date {
        judgedFrom(project.startedAt, sessions: project.sessions, calendar: calendar)
    }

    private static func judgedFrom(
        _ created: Date,
        sessions: [Session],
        calendar: Calendar
    ) -> Date {
        let createdDay = calendar.startOfDay(for: created)
        guard let earliest = sessions.map(\.startedAt).min() else {
            return createdDay
        }
        return min(createdDay, calendar.startOfDay(for: earliest))
    }
}

// MARK: - Tally Judgment

extension GoalCalendar {
    /// Judges every day of the month across `metrics`: how many daily goals
    /// applied and how many were reached. Callers pass the metrics whose
    /// goals count (Today's convention: the unarchived ones); a metric
    /// without a daily target never enters a day's total, and each metric
    /// counts only from its own tracking start.
    static func tallies(
        for metrics: [Metric],
        monthOf date: Date,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [Date: DayTally] {
        let judged = metrics.map {
            outcomes(for: $0, sessions: $0.sessions, monthOf: date, now: now, calendar: calendar)
        }
        var result: [Date: DayTally] = [:]
        for day in days(inMonthOf: date, calendar: calendar) {
            result[day] = tally(on: day, across: judged)
        }
        return result
    }

    private static func tally(
        on day: Date,
        across judged: [[Date: DayOutcome]]
    ) -> DayTally {
        var met = 0
        var total = 0
        for outcomes in judged {
            switch outcomes[day]?.verdict {
            case .met:
                met += 1
                total += 1
            case .missed:
                total += 1
            default:
                break
            }
        }
        return DayTally(met: met, total: total)
    }
}

// MARK: - Judgment Internals

private extension GoalCalendar {
    /// The per-series facts every day's verdict reads.
    struct SeriesContext {
        let metric: Metric
        let trackingStart: Date
        let today: Date
        let calendar: Calendar
    }

    static func makeContext(
        for metric: Metric,
        since: Date?,
        now: Date,
        calendar: Calendar
    ) -> SeriesContext {
        SeriesContext(
            metric: metric,
            trackingStart: since ?? trackingStart(of: metric, calendar: calendar),
            today: calendar.startOfDay(for: now),
            calendar: calendar
        )
    }

    static func verdict(
        value: Double,
        on day: Date,
        in context: SeriesContext
    ) -> Verdict {
        guard isJudged(on: day, in: context) else { return .free }
        guard context.metric.isGoalDay(on: day, calendar: context.calendar) else {
            return .rest
        }
        return isMet(value: value, for: context.metric) ? .met : .missed
    }

    /// Whether the day carries a verdict at all: not ahead of today, not
    /// before the series began, and the metric holds a daily target — the
    /// same target rule `GoalSummary` counts by.
    static func isJudged(on day: Date, in context: SeriesContext) -> Bool {
        day <= context.today && day >= context.trackingStart
            && GoalSummary.hasDailyTarget(context.metric)
    }

    /// The met arithmetic of `GoalSummary.isDailyMet`, applied to an
    /// already-summed value so a project's slice can be judged too.
    static func isMet(value: Double, for metric: Metric) -> Bool {
        if metric.measurementType == .binary {
            return value > 0
        }
        return value >= (metric.dailyGoal ?? 0)
    }

    /// Completed-session totals keyed by day start — the same grouping as
    /// `SessionStatistics.dailyTotals`, as a lookup table.
    static func dayTotals(
        of sessions: [Session],
        calendar: Calendar
    ) -> [Date: Double] {
        var totals: [Date: Double] = [:]
        for session in sessions where !session.isRunning {
            let day = calendar.startOfDay(for: session.startedAt)
            totals[day, default: 0] += session.trackingValue
        }
        return totals
    }
}
