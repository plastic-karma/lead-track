import Foundation

/// The live, recomputed progress of one intention inside its week — built
/// fresh on every render, never stored as a running tally (the
/// `AspirationRollup` doctrine: a retroactive import, an undone tick, or a
/// deleted session must instantly re-total).
///
/// Progress is only ever accumulation ("4 of 7 days"), never deficit: there
/// is no pace, no projection, and no over-target styling — exceeding a target
/// simply reads "5 of 3".
struct IntentionProgress: Equatable {
    /// What accumulated so far: ticks, qualifying sessions, summed value, or
    /// distinct eligible days.
    let value: Double
    /// What it accumulates toward: the weekly target, or the eligible-day
    /// count for per-day intentions.
    let target: Double
    /// The factual reading: "2 of 3", "4 of 7 days", "1h 40m of 4h 00m".
    let text: String
}

// MARK: - Computation

extension IntentionProgress {
    /// Progress for the intention, or nil where none exists: reflective
    /// intentions have no progress value (deliberately — do not synthesize
    /// one), and a derived intention whose metric was deleted reads
    /// "source removed" instead.
    static func compute(
        for intention: Intention,
        calendar: Calendar = .current
    ) -> IntentionProgress? {
        switch intention.kind {
        case .reflective:
            return nil
        case .counted:
            return counted(intention, calendar: calendar)
        case .derived:
            return derived(intention, calendar: calendar)
        }
    }

    private static func counted(_ intention: Intention, calendar: Calendar) -> IntentionProgress {
        if intention.perDay {
            return perDayProgress(over: intention.tickDates, of: intention, calendar: calendar)
        }
        return weeklyCount(intention.tickDates.count, of: intention)
    }

    private static func derived(_ intention: Intention, calendar: Calendar) -> IntentionProgress? {
        guard let metric = intention.metric, let mode = intention.derivedMode else { return nil }
        let sessions = qualifyingSessions(of: metric, in: intention.weekInterval(calendar: calendar))
        switch mode {
        case .sessionCount:
            if intention.perDay {
                return perDayProgress(over: sessions.map(\.startedAt), of: intention, calendar: calendar)
            }
            return weeklyCount(sessions.count, of: intention)
        case .valueSum:
            let sum = sessions.reduce(0) { $0 + $1.trackingValue }
            return valueSum(sum, of: intention, metric: metric)
        }
    }
}

// MARK: - Qualification

extension IntentionProgress {
    /// The completed sessions a derived intention consumes: attributed to the
    /// week by `startedAt` (the `SessionStatistics` convention, half-open),
    /// belonging to the metric directly or through one of its projects, and
    /// de-duplicated so a session counts once (the `ContributionSource`
    /// approach). Running sessions never count until completed.
    static func qualifyingSessions(of metric: Metric, in week: DateInterval) -> [Session] {
        var seen = Set<ObjectIdentifier>()
        let candidates = metric.sessions + metric.projects.flatMap(\.sessions)
        return candidates.filter { session in
            !session.isRunning
                && session.startedAt >= week.start && session.startedAt < week.end
                && seen.insert(ObjectIdentifier(session)).inserted
        }
    }

    /// The calendar days a per-day intention is answerable for: from its
    /// creation day (not the week start — the app never manufactures a
    /// deficit for days that predate the commitment) through the end of its
    /// week. Bucketing is by `startOfDay`, so DST weeks keep seven days and
    /// midnight ticks land where the clock says.
    static func eligibleDays(of intention: Intention, calendar: Calendar = .current) -> [Date] {
        let week = intention.weekInterval(calendar: calendar)
        var day = max(week.start, calendar.startOfDay(for: intention.createdAt))
        var days: [Date] = []
        while day < week.end {
            days.append(day)
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return days
    }
}

// MARK: - Readings

private extension IntentionProgress {
    /// Distinct eligible days containing at least one of `dates`, toward the
    /// eligible-day count. Extra same-day entries are recorded but do not
    /// advance the day count.
    static func perDayProgress(over dates: [Date], of intention: Intention, calendar: Calendar) -> IntentionProgress {
        let eligible = eligibleDays(of: intention, calendar: calendar)
        let covered = Set(dates.map { calendar.startOfDay(for: $0) })
        let done = eligible.count { covered.contains($0) }
        return IntentionProgress(
            value: Double(done),
            target: Double(eligible.count),
            text: "\(done) of \(eligible.count) \(eligible.count == 1 ? "day" : "days")"
        )
    }

    static func weeklyCount(_ count: Int, of intention: Intention) -> IntentionProgress {
        let target = intention.target ?? 0
        return IntentionProgress(
            value: Double(count),
            target: target,
            text: "\(count) of \(Int(target))"
        )
    }

    static func valueSum(_ sum: Double, of intention: Intention, metric: Metric) -> IntentionProgress {
        let target = intention.target ?? 0
        let text = metric.measurementType == .duration
            ? "\(DurationFormatter.format(sum)) of \(DurationFormatter.format(target))"
            : "\(Int(sum)) of \(ValueFormatter.format(target, type: .count, unit: metric.unit))"
        return IntentionProgress(value: sum, target: target, text: text)
    }
}
