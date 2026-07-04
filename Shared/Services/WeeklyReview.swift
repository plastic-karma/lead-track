import Foundation

/// Everything the weekly review screen shows, assembled once from the metrics
/// and aspirations: the aspiration lens (what landed in the reviewed seven
/// days — lifetime totals stay on the aspiration's own screen), one swipeable
/// page of insights per active metric, the ones that stayed quiet, and the
/// combined pulse for the header. Aspirations are additive — with none
/// attached the review is exactly the metric review it always was. Pure data,
/// so the assembly is unit-testable (including on Linux).
struct WeeklyReview {
    /// Start of the oldest day in the period.
    let start: Date
    /// The latest moment the review covers: now for the current week, the
    /// final day for an earlier one.
    let end: Date
    /// How many weeks before the current one this review describes.
    let weeksBack: Int
    let metricWeeks: [MetricWeek]
    let quietMetrics: [QuietMetric]
    /// Active aspirations this week — the review's centerpiece when any exist.
    let aspirationWeeks: [AspirationWeek]
    /// Aspirations that logged nothing this week.
    let quietAspirations: [QuietAspiration]
    /// Unclosed intentions from the most recently completed week, awaiting
    /// closure. Empty when the feature is unused — additive, never a fork.
    let intentionClosures: [IntentionClosure]
    /// Goal seasons awaiting their renew/adjust/retire decision — live review
    /// only, and empty while the feature is unused (see `GoalSeason`).
    let goalSeasonReviews: [GoalSeason.Review]
    /// Completed sessions per day across all metrics, oldest first.
    let sessionSeries: [Double]
}

// MARK: - Header Aggregates

extension WeeklyReview {
    /// Total tracked time across duration metrics; counts don't mix in.
    var totalDuration: TimeInterval {
        metricWeeks
            .filter { $0.measurementType == .duration }
            .reduce(0) { $0 + $1.total }
    }

    var sessionCount: Int {
        metricWeeks.reduce(0) { $0 + $1.sessionCount }
    }

    /// Days in the period with at least one completed session in any metric.
    var activeDays: Int {
        sessionSeries.count { $0 > 0 }
    }

    /// Offset into the period of the day with the most sessions.
    var busiestDayOffset: Int? {
        guard let maxValue = sessionSeries.max(), maxValue > 0 else { return nil }
        return sessionSeries.firstIndex(of: maxValue)
    }

    /// The calendar day at the given offset into the period.
    func day(at offset: Int, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: offset, to: start) ?? start
    }
}

// MARK: - Assembly

extension WeeklyReview {
    static let periodDays = 7

    /// Relative change below which a week reads as "about the same".
    private static let flatThreshold = 0.05

    static func build(
        metrics: [Metric],
        aspirations: [Aspiration] = [],
        intentions: [Intention] = [],
        checkIns: [AspirationCheckIn] = [],
        moments: [Moment] = [],
        weeksBack: Int = 0,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> WeeklyReview {
        let bounds = PeriodBounds(weeksBack: weeksBack, now: now, calendar: calendar)
        let metricSplit = partitionMetrics(metrics, bounds: bounds, calendar: calendar)
        let closures = intentionClosures(
            from: intentions, weeksBack: weeksBack, now: now, calendar: calendar
        )
        let context = AspirationWeekContext(
            bounds: bounds, now: now, calendar: calendar,
            intentions: intentions, closureOwners: Set(closures.map(\.aspirationID)),
            checkedInOwners: checkedInOwners(of: checkIns, now: now, calendar: calendar),
            moments: moments
        )
        let aspirationSplit = partitionAspirations(aspirations, context: context)
        return WeeklyReview(
            start: bounds.start,
            end: bounds.displayEnd,
            weeksBack: weeksBack,
            metricWeeks: metricSplit.weeks,
            quietMetrics: metricSplit.quiet,
            aspirationWeeks: aspirationSplit.weeks,
            quietAspirations: aspirationSplit.quiet,
            intentionClosures: closures,
            goalSeasonReviews: bounds.isCurrentWeek
                ? GoalSeason.reviews(for: metrics, aspirations: aspirations, now: now, calendar: calendar)
                : [],
            sessionSeries: combinedSessionSeries(metrics: metrics, bounds: bounds, calendar: calendar)
        )
    }

    /// Aspiration IDs that already checked in during the calendar week
    /// containing `now`, so the live review offers the pulse only where it is
    /// still open.
    static func checkedInOwners(
        of checkIns: [AspirationCheckIn],
        now: Date,
        calendar: Calendar
    ) -> Set<String> {
        let week = Intention.weekStart(containing: now, calendar: calendar)
        return Set(
            checkIns
                .filter { $0.weekStart == week }
                .compactMap { $0.aspiration.map { stableID(of: $0) } }
        )
    }
}

// MARK: - Assembly Pieces

extension WeeklyReview {
    /// The reviewed period, the comparison period before it, and its end —
    /// half-open, so a session at the next week's first midnight stays out.
    /// Internal (not private) so the aspiration lens in its own file windows
    /// with exactly the same rules.
    struct PeriodBounds {
        let start: Date
        let previousStart: Date
        /// Exclusive upper bound for sessions in the period.
        let end: Date
        /// The latest moment shown: the open end for the current week, the
        /// anchor day itself for an earlier one.
        let displayEnd: Date
        /// Whether the period is the week ending today.
        let isCurrentWeek: Bool

        init(weeksBack: Int, now: Date, calendar: Calendar) {
            let today = calendar.startOfDay(for: now)
            let anchor = calendar.date(byAdding: .day, value: -periodDays * weeksBack, to: today) ?? today
            start = calendar.date(byAdding: .day, value: -(periodDays - 1), to: anchor) ?? anchor
            previousStart = calendar.date(byAdding: .day, value: -periodDays, to: start) ?? start
            isCurrentWeek = weeksBack == 0
            end = isCurrentWeek
                ? now
                : calendar.date(byAdding: .day, value: 1, to: anchor) ?? anchor
            displayEnd = isCurrentWeek ? now : anchor
        }

        func currentSessions(of metric: Metric) -> [Session] {
            current(in: metric.sessions)
        }

        /// Completed sessions of `sessions` inside the reviewed period.
        func current(in sessions: [Session]) -> [Session] {
            sessions.filter {
                !$0.isRunning && $0.startedAt >= start && $0.startedAt < end
            }
        }

        /// Completed sessions of `sessions` inside the comparison period before it.
        func previous(in sessions: [Session]) -> [Session] {
            sessions.filter {
                !$0.isRunning && $0.startedAt >= previousStart && $0.startedAt < start
            }
        }
    }

    static func activeDays(in sessions: [Session], calendar: Calendar) -> Int {
        Set(sessions.map { calendar.startOfDay(for: $0.startedAt) }).count
    }

    /// Per-day sums of `value` over the period, zero-filled, oldest first.
    static func dailyValues(
        of sessions: [Session],
        from start: Date,
        calendar: Calendar,
        value: (Session) -> Double
    ) -> [Double] {
        var byDay: [Date: Double] = [:]
        for session in sessions {
            byDay[calendar.startOfDay(for: session.startedAt), default: 0] += value(session)
        }
        return (0 ..< periodDays).map { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: start)
            else { return 0 }
            return byDay[day] ?? 0
        }
    }

    static func stableID(of metric: Metric) -> String {
        metric.stableID?.uuidString ?? metric.name
    }

    static func stableID(of aspiration: Aspiration) -> String {
        aspiration.stableID?.uuidString ?? aspiration.title
    }
}

private extension WeeklyReview {
    static func partitionMetrics(
        _ metrics: [Metric],
        bounds: PeriodBounds,
        calendar: Calendar
    ) -> (weeks: [MetricWeek], quiet: [QuietMetric]) {
        var weeks: [MetricWeek] = []
        var quiet: [QuietMetric] = []
        for metric in metrics {
            if let week = metricWeek(for: metric, bounds: bounds, calendar: calendar) {
                weeks.append(week)
            } else {
                quiet.append(QuietMetric(
                    id: stableID(of: metric), name: metric.name, icon: metric.displayIcon
                ))
            }
        }
        return (weeks, quiet)
    }

    static func metricWeek(
        for metric: Metric,
        bounds: PeriodBounds,
        calendar: Calendar
    ) -> MetricWeek? {
        let current = bounds.currentSessions(of: metric)
        guard !current.isEmpty else { return nil }
        let total = current.reduce(0) { $0 + $1.trackingValue }
        let previousTotal = bounds.previous(in: metric.sessions)
            .reduce(0) { $0 + $1.trackingValue }
        return MetricWeek(
            id: stableID(of: metric),
            name: metric.name,
            icon: metric.displayIcon,
            colorName: metric.colorName,
            measurementType: metric.measurementType,
            unit: metric.unit,
            total: total,
            change: classifyChange(total: total, previous: previousTotal),
            sessionCount: current.count,
            activeDays: activeDays(in: current, calendar: calendar),
            dailySeries: dailyValues(of: current, from: bounds.start, calendar: calendar) { $0.trackingValue },
            streak: bounds.isCurrentWeek ? streak(of: metric) : 0,
            goalDaysHit: goalDaysHit(of: metric, current: current),
            insights: InsightGenerator.generate(
                for: metric,
                currentStart: bounds.start,
                previousStart: bounds.previousStart,
                end: bounds.end
            )
        )
    }

    static func classifyChange(total: Double, previous: Double) -> WeekChange {
        guard previous > 0 else { return .noBaseline }
        let ratio = (total - previous) / previous
        guard abs(ratio) >= flatThreshold else { return .flat }
        return ratio > 0 ? .up(ratio: ratio) : .down(ratio: ratio)
    }

    static func streak(of metric: Metric) -> Int {
        SessionStatistics.currentStreak(
            from: SessionStatistics.dailyTotals(from: metric.sessions),
            excludedWeekdays: metric.excludedWeekdaySet
        )
    }

    static func goalDaysHit(of metric: Metric, current: [Session]) -> Int? {
        metric.dailyGoal.map { goal in
            SessionStatistics.dailyTotals(from: current)
                .count { $0.duration >= goal }
        }
    }

    static func combinedSessionSeries(
        metrics: [Metric],
        bounds: PeriodBounds,
        calendar: Calendar
    ) -> [Double] {
        let sessions = metrics.flatMap { bounds.currentSessions(of: $0) }
        return dailyValues(of: sessions, from: bounds.start, calendar: calendar) { _ in 1 }
    }
}
