import Foundation

/// The check-in trend math — the Goodhart alarm. Effort trending up while
/// alignment trends down means the measures are being fed instead of the
/// aspiration. Pure and deliberately crude: with at most a handful of
/// subjective points, half-window means and endpoint ratings are all the
/// resolution the data honestly supports — anything fancier is false
/// precision. Every guard makes silence the default; sparse data yields nil,
/// never a guess.
enum AspirationAlignment {
    /// Lifetime check-ins before anything trend-like is shown.
    static let minimumCheckIns = 4
    static let divergenceWindowWeeks = 6
    /// Weeks of history the pulse strip renders.
    static let historyWeeks = 12

    /// One calendar week's rating, keyed by the week's normalized start.
    struct WeekPoint: Equatable {
        let weekStart: Date
        let rating: Int
    }

    /// Ratings keyed to calendar weeks, oldest first, one per week (the
    /// latest edit wins), gaps preserved as absent weeks.
    /// Grouping is purely by the persisted `weekStart` key, so no calendar
    /// is involved — the parameter a previous shape advertised and ignored
    /// is gone rather than misleading callers.
    static func series(
        from checkIns: [AspirationCheckIn]
    ) -> [WeekPoint] {
        Dictionary(grouping: checkIns, by: \.weekStart)
            .compactMap { week, items -> WeekPoint? in
                guard let latest = items.max(by: { $0.createdAt < $1.createdAt })
                else { return nil }
                return WeekPoint(weekStart: week, rating: latest.ratingRaw)
            }
            .sorted { $0.weekStart < $1.weekStart }
    }

    /// Sessions per calendar week across the aspiration's de-duped
    /// contribution sources — the unit-blind effort proxy (units can't mix;
    /// session count can). Oldest first, zero-filled, the week containing
    /// `now` last.
    static func effortSeries(
        for aspiration: Aspiration,
        weeks: Int,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [Double] {
        let starts = trailingWeekStarts(weeks: weeks, now: now, calendar: calendar)
        guard let windowStart = starts.first else { return [] }
        var counts: [Date: Double] = [:]
        for source in AspirationRollup.contributionSources(of: aspiration) {
            let counted = source.sessions.filter { !$0.isRunning && $0.startedAt >= windowStart }
            for session in counted {
                let week = Intention.weekStart(containing: session.startedAt, calendar: calendar)
                counts[week, default: 0] += 1
            }
        }
        return starts.map { counts[$0] ?? 0 }
    }

    /// The normalized starts of the trailing `weeks` calendar weeks, oldest
    /// first, ending with the week containing `now`.
    static func trailingWeekStarts(weeks: Int, now: Date, calendar: Calendar) -> [Date] {
        let current = Intention.weekStart(containing: now, calendar: calendar)
        return (0 ..< weeks).reversed().compactMap {
            calendar.date(byAdding: .weekOfYear, value: -$0, to: current)
        }
    }

    /// The aspiration's check-in for the calendar week containing `now`, if
    /// any — the row the composer edits (one per week, latest edit wins).
    static func currentWeekCheckIn(
        of aspiration: Aspiration,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> AspirationCheckIn? {
        return aspiration.checkIns
            .filter { Intention.week(starting: $0.weekStart, contains: now, calendar: calendar) }
            .max { $0.createdAt < $1.createdAt }
    }
}

// MARK: - Divergence

extension AspirationAlignment {
    struct Divergence: Equatable {
        let windowWeeks: Int
        /// Second-half weekly-effort mean over the first-half mean.
        let effortChangeRatio: Double
        let firstRating: Int
        let lastRating: Int
    }

    /// Non-nil only when, over the trailing window: (a) enough ratings exist,
    /// (b) they fell by at least one full step from the window's first to its
    /// last, and (c) weekly effort was flat or rising — the measures being
    /// fed while the why is served less. Sparse data yields nil, always.
    static func divergence(
        alignment: [WeekPoint],
        effort: [Double],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Divergence? {
        let starts = trailingWeekStarts(weeks: divergenceWindowWeeks, now: now, calendar: calendar)
        guard let windowStart = starts.first else { return nil }
        let window = alignment.filter { $0.weekStart >= windowStart }
        guard window.count >= minimumCheckIns,
              let first = window.first, let last = window.last,
              first.rating - last.rating >= 1,
              let ratio = flatOrRisingRatio(of: Array(effort.suffix(divergenceWindowWeeks)))
        else { return nil }
        return Divergence(
            windowWeeks: divergenceWindowWeeks,
            effortChangeRatio: ratio,
            firstRating: first.rating,
            lastRating: last.rating
        )
    }

    /// The second-half over first-half effort ratio, nil when effort fell —
    /// or when the window logged nothing at all, which must never read as
    /// "flat".
    private static func flatOrRisingRatio(of effort: [Double]) -> Double? {
        guard !effort.isEmpty, effort.reduce(0, +) > 0 else { return nil }
        let half = effort.count / 2
        let firstMean = mean(of: Array(effort.prefix(half)))
        let secondMean = mean(of: Array(effort.suffix(effort.count - half)))
        guard secondMean >= firstMean else { return nil }
        return firstMean > 0 ? secondMean / firstMean : 1
    }

    private static func mean(of values: [Double]) -> Double {
        values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
    }
}
