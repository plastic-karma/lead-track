import Foundation

/// The slice of the export data one report covers: everything at or after
/// the range's cutoff, bucketed into calendar weeks — the same
/// `dateInterval(of: .weekOfYear)` convention every other week surface uses.
struct MarkdownExportWindow {
    /// All metrics in their incoming (creation) order, kept so day, week,
    /// and totals lines list metrics identically.
    let metrics: [Metric]
    let sessions: [Session]
    let moments: [Moment]
    let intentions: [Intention]
    let checkIns: [AspirationCheckIn]
    let weeks: [MarkdownExportWeek]
    let calendar: Calendar

    init(
        data: MarkdownExportData,
        range: ExportRange,
        now: Date = .now,
        calendar: Calendar = .current
    ) {
        self.calendar = calendar
        metrics = data.metrics
        let cutoff = range.cutoff(now: now, calendar: calendar)
        sessions = Self.completedSessions(of: data.metrics, since: cutoff)
        moments = data.moments
            .filter { moment in cutoff.map { moment.occurredAt >= $0 } ?? true }
            .sorted { $0.occurredAt < $1.occurredAt }
        // A week belongs to the report when any part of it is inside the
        // range, so a mid-week cutoff still brings that week's commitments.
        let weekFloor = cutoff.map { Intention.weekStart(containing: $0, calendar: calendar) }
        intentions = data.intentions
            .filter { intention in weekFloor.map { intention.weekStart >= $0 } ?? true }
            .sorted { $0.createdAt < $1.createdAt }
        checkIns = data.checkIns
            .filter { checkIn in weekFloor.map { checkIn.weekStart >= $0 } ?? true }
            .sorted { $0.createdAt < $1.createdAt }
        weeks = MarkdownExportWeekBuilder(
            sessions: sessions,
            moments: moments,
            intentions: intentions,
            checkIns: checkIns,
            calendar: calendar
        ).build()
    }

    /// Whether the range holds anything to narrate — the export form's
    /// empty-state check.
    var isEmpty: Bool {
        weeks.isEmpty
    }
}

// MARK: - Session Collection

extension MarkdownExportWindow {
    /// The completed sessions the report aggregates, gathered by the shared
    /// `SessionCollection` rule and sorted oldest first.
    static func completedSessions(of metrics: [Metric], since cutoff: Date?) -> [Session] {
        SessionCollection.completedSessions(
            of: metrics,
            startingIn: cutoff.map { DateInterval(start: $0, end: .distantFuture) }
        )
        .sorted { $0.startedAt < $1.startedAt }
    }
}

/// One calendar week of the report, oldest day first.
struct MarkdownExportWeek {
    let interval: DateInterval
    let sessions: [Session]
    let intentions: [Intention]
    let checkIns: [AspirationCheckIn]
    let days: [MarkdownExportDay]
}

/// One day inside a week — present only when something happened on it.
struct MarkdownExportDay {
    let day: Date
    let sessions: [Session]
    let moments: [Moment]
}

/// Groups a window's contents into `MarkdownExportWeek`s: the union of every
/// week touched by a session, moment, intention, or check-in, ascending.
struct MarkdownExportWeekBuilder {
    let sessions: [Session]
    let moments: [Moment]
    let intentions: [Intention]
    let checkIns: [AspirationCheckIn]
    let calendar: Calendar

    func build() -> [MarkdownExportWeek] {
        weekStarts().map(week(startingAt:))
    }

    private func weekStarts() -> [Date] {
        var starts = Set<Date>()
        starts.formUnion(sessions.map { start(containing: $0.startedAt) })
        starts.formUnion(moments.map { start(containing: $0.occurredAt) })
        starts.formUnion(intentions.map { start(containing: $0.weekStart) })
        starts.formUnion(checkIns.map { start(containing: $0.weekStart) })
        return starts.sorted()
    }

    private func week(startingAt weekStart: Date) -> MarkdownExportWeek {
        let interval = calendar.dateInterval(of: .weekOfYear, for: weekStart)
            ?? DateInterval(start: weekStart, duration: 7 * 24 * 3600)
        let weekSessions = sessions.filter { interval.holds($0.startedAt) }
        let weekMoments = moments.filter { interval.holds($0.occurredAt) }
        return MarkdownExportWeek(
            interval: interval,
            sessions: weekSessions,
            intentions: intentions.filter { start(containing: $0.weekStart) == weekStart },
            checkIns: checkIns.filter { start(containing: $0.weekStart) == weekStart },
            days: days(sessions: weekSessions, moments: weekMoments)
        )
    }

    /// The week's populated days: the union of days carrying a session or a
    /// moment, ascending, with each day's contents attached.
    private func days(sessions: [Session], moments: [Moment]) -> [MarkdownExportDay] {
        let sessionDays = Dictionary(grouping: sessions) { calendar.startOfDay(for: $0.startedAt) }
        let momentDays = Dictionary(grouping: moments) { calendar.startOfDay(for: $0.occurredAt) }
        return Set(sessionDays.keys).union(momentDays.keys).sorted().map { day in
            MarkdownExportDay(
                day: day,
                sessions: sessionDays[day] ?? [],
                moments: momentDays[day] ?? []
            )
        }
    }

    private func start(containing date: Date) -> Date {
        Intention.weekStart(containing: date, calendar: calendar)
    }
}

private extension DateInterval {
    /// Half-open containment, like every week window in the app —
    /// `DateInterval.contains` would admit the next week's first midnight.
    func holds(_ date: Date) -> Bool {
        date >= start && date < end
    }
}
