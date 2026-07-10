import Foundation

/// Measure-health detectors — the fingerprints a target leaves on behavior
/// when the number, not the aspiration, is doing the steering. The copy
/// discipline is absolute: question the measure, never the user; every detail
/// ends in a question. Guards are strict enough that silence is the norm —
/// a false Goodhart accusation is worse than a missed one.
///
/// Two scopes, one tone: the metric-shaped detectors feed `InsightGenerator`
/// (whose category cap keeps them to one per metric per week); the narrowing
/// detector is aspiration-shaped and feeds the review card and the
/// aspiration detail directly.
enum MeasureHealth {
    static let lookbackDays = 28
    /// Hit-days within +15% of the goal line count as hugging it.
    static let clusterBand = 0.15
    /// Share of hit-days that must land in the band.
    static let clusterShare = 0.7
    static let minHitDays = 8
    /// A save is at most this share of the metric's median session.
    static let saverValueShare = 0.25
    static let saverMinStreak = 7
    static let saverMinOccurrences = 2
    /// Sessions starting at or after this hour count as late.
    static let saverLateHour = 21
    static let monocultureWindowDays = 30
    static let monocultureShare = 0.75
    static let monocultureMinQuietSources = 2
    static let monocultureMinSessions = 12
    static let monocultureMinSources = 3
}

// MARK: - Goal clustering

extension MeasureHealth {
    /// Daily totals hugging the goal line: of the last 28 days' goal-day
    /// hits, at least 70% landed within [goal, goal × 1.15], over at least 8
    /// hit-days. Quantity metrics with a daily goal and 28+ days of history
    /// only — a user who naturally stops near a well-sized goal for a single
    /// week never triggers.
    static func detectGoalClustering(
        metric: Metric,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Insight? {
        guard let goal = metric.dailyGoal, goal > 0,
              metric.measurementType.tracksQuantity,
              hasHistory(metric, days: lookbackDays, now: now, calendar: calendar)
        else { return nil }
        let hits = SessionStatistics.dailyTotals(from: metric.sessions, calendar: calendar)
            .filter { inWindow($0.date, days: lookbackDays, now: now, calendar: calendar) }
            .filter { metric.isGoalDay(on: $0.date, calendar: calendar) && $0.duration >= goal }
        guard hits.count >= minHitDays else { return nil }
        let banded = hits.count { $0.duration <= goal * (1 + clusterBand) }
        guard Double(banded) / Double(hits.count) >= clusterShare else { return nil }
        return .goalClustering(bandedHits: banded, totalHits: hits.count)
    }
}

// MARK: - Streak saver

extension MeasureHealth {
    /// Sole-session days whose value was a quarter of the metric's median,
    /// landing late while a long streak was alive — the chain being fed, not
    /// the why. Excluded for binary metrics (the value is always 1) and
    /// health-linked ones (their sessions are mirrored, not chosen).
    static func detectStreakSaver(
        metric: Metric,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Insight? {
        guard metric.measurementType.tracksQuantity, !metric.isHealthLinked,
              hasHistory(metric, days: lookbackDays, now: now, calendar: calendar)
        else { return nil }
        // The streak as of `now`, not of today — browsing an earlier week's
        // review must judge the streak that was alive back then.
        let streak = SessionStatistics.currentStreak(
            from: SessionStatistics.dailyTotals(from: metric.sessions, calendar: calendar),
            excludedWeekdays: metric.excludedWeekdaySet,
            now: now,
            calendar: calendar
        )
        guard streak >= saverMinStreak,
              let median = medianSessionValue(of: metric)
        else { return nil }
        let saves = saveDays(of: metric, ceiling: median * saverValueShare, now: now, calendar: calendar)
        guard saves >= saverMinOccurrences else { return nil }
        return .streakSaver(occurrences: saves, streak: streak)
    }

    private static func medianSessionValue(of metric: Metric) -> Double? {
        let values = metric.sessions
            .filter { !$0.isRunning }
            .map(\.trackingValue)
            .sorted()
        guard !values.isEmpty else { return nil }
        let upper = values.count / 2
        guard values.count.isMultiple(of: 2) else { return values[upper] }
        return (values[upper - 1] + values[upper]) / 2
    }

    /// Days in the window whose only session was tiny and late.
    private static func saveDays(
        of metric: Metric,
        ceiling: Double,
        now: Date,
        calendar: Calendar
    ) -> Int {
        let completed = metric.sessions.filter {
            !$0.isRunning
                && inWindow(calendar.startOfDay(for: $0.startedAt), days: lookbackDays, now: now, calendar: calendar)
        }
        let byDay = Dictionary(grouping: completed) { calendar.startOfDay(for: $0.startedAt) }
        return byDay.values.count { sessions in
            guard sessions.count == 1, let only = sessions.first else { return false }
            return only.trackingValue <= ceiling
                && calendar.component(.hour, from: only.startedAt) >= saverLateHour
        }
    }
}

// MARK: - Shared guards

extension MeasureHealth {
    /// Both metric detectors need a month of history before saying anything.
    private static func hasHistory(
        _ metric: Metric,
        days: Int,
        now: Date,
        calendar: Calendar
    ) -> Bool {
        guard let first = metric.sessions
            .filter({ !$0.isRunning })
            .map(\.startedAt)
            .min(),
            let cutoff = calendar.date(byAdding: .day, value: -days, to: now)
        else { return false }
        return first <= cutoff
    }

    private static func inWindow(
        _ date: Date,
        days: Int,
        now: Date,
        calendar: Calendar
    ) -> Bool {
        guard let cutoff = calendar.date(
            byAdding: .day, value: -(days - 1), to: calendar.startOfDay(for: now)
        ) else { return false }
        return date >= cutoff && date <= now
    }
}

// MARK: - Narrowing

extension MeasureHealth {
    /// One attachment carrying nearly all of a month's sessions while
    /// previously-active attachments went quiet. Reframed from "cheapest
    /// metric" — no cost model exists, so dominance-plus-quiet is what the
    /// data can defend.
    struct Narrowing: Equatable {
        let dominantName: String
        let dominantShare: Double
        let quietNames: [String]
    }

    /// Aspiration narrowing: over the trailing 30 days one de-duped source
    /// carries at least 75% of sessions (12+ total) while two or more sources
    /// active in the prior 30 days logged nothing. Needs three ever-active
    /// sources, so a naturally small mix stays silent.
    static func detectNarrowing(
        for aspiration: Aspiration,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Narrowing? {
        let counted = AspirationRollup.contributionSources(of: aspiration)
            .map { CountedSource(source: $0, now: now, calendar: calendar) }
        guard counted.count(where: \.everActive) >= monocultureMinSources else { return nil }
        let total = counted.reduce(0) { $0 + $1.recent }
        guard total >= monocultureMinSessions,
              let dominant = counted.max(by: { $0.recent < $1.recent }),
              Double(dominant.recent) / Double(total) >= monocultureShare
        else { return nil }
        let quiet = counted.filter { $0.prior > 0 && $0.recent == 0 }.map(\.name)
        guard quiet.count >= monocultureMinQuietSources else { return nil }
        return Narrowing(
            dominantName: dominant.name,
            dominantShare: Double(dominant.recent) / Double(total),
            quietNames: quiet
        )
    }

    /// One source's completed-session counts in the recent and prior windows,
    /// both day-aligned via the calendar like every other window in this file.
    private struct CountedSource {
        let name: String
        let recent: Int
        let prior: Int
        let everActive: Bool

        init(source: ContributionSource, now: Date, calendar: Calendar) {
            let completed = source.sessions.filter { !$0.isRunning }
            let today = calendar.startOfDay(for: now)
            let days = MeasureHealth.monocultureWindowDays
            let recentStart = calendar.date(byAdding: .day, value: -days, to: today) ?? today
            let priorStart = calendar.date(byAdding: .day, value: -2 * days, to: today) ?? recentStart
            name = source.name
            recent = completed.count { $0.startedAt >= recentStart && $0.startedAt < now }
            prior = completed.count { $0.startedAt >= priorStart && $0.startedAt < recentStart }
            everActive = !completed.isEmpty
        }
    }
}

extension MeasureHealth.Narrowing {
    /// The one quiet line surfaces render — the factual share, then the
    /// question. Never an accusation.
    var line: String {
        let percent = Int((dominantShare * 100).rounded())
        let quiet = quietNames.joined(separator: ", ")
        return "\(dominantName) carried \(percent)% of the last month here, "
            + "while \(quiet) went quiet. Is the mix still serving the why?"
    }
}
