import Foundation

// The aspiration lens of the weekly review, assembled the same additive way
// as the intention layer: with no aspirations the review is byte-identical to
// the metric review it always was. An aspiration takes the stage when its
// week has anything to say — effort logged, intentions in play, or closures
// awaiting a decision — and rests in the quiet list otherwise.

extension WeeklyReview {
    /// Everything the aspiration partition needs beyond the aspirations
    /// themselves: the reviewed window and the week's intention state.
    struct AspirationWeekContext {
        let bounds: PeriodBounds
        let now: Date
        let calendar: Calendar
        /// Every intention, from which each aspiration's open lines are drawn.
        let intentions: [Intention]
        /// Aspiration IDs with unclosed intentions awaiting this review.
        let closureOwners: Set<String>
        /// Aspiration IDs that already recorded this week's alignment pulse.
        let checkedInOwners: Set<String>
    }

    static func partitionAspirations(
        _ aspirations: [Aspiration],
        context: AspirationWeekContext
    ) -> (weeks: [AspirationWeek], quiet: [QuietAspiration]) {
        var weeks: [AspirationWeek] = []
        var quiet: [QuietAspiration] = []
        for aspiration in aspirations {
            if let week = aspirationWeek(aspiration, context: context) {
                weeks.append(week)
            } else {
                quiet.append(QuietAspiration(
                    id: stableID(of: aspiration), title: aspiration.title,
                    icon: aspiration.displayIcon
                ))
            }
        }
        return (weeks, quiet)
    }

    /// One aspiration's week, or `nil` when it has nothing on stage — no
    /// effort in the window, no open intentions, no pending closures — and
    /// falls to the quiet list.
    static func aspirationWeek(
        _ aspiration: Aspiration,
        context: AspirationWeekContext
    ) -> AspirationWeek? {
        let week = weekData(of: aspiration, context: context)
        let awaitsClosure = context.closureOwners.contains(week.id)
        guard week.sessionCount > 0 || !week.intentions.isEmpty || awaitsClosure else { return nil }
        return week
    }
}

// MARK: - Week assembly

private extension WeeklyReview {
    /// The week itself, built unconditionally — the staging rule above and
    /// the drill-in detail below share this core.
    static func weekData(
        of aspiration: Aspiration,
        context: AspirationWeekContext
    ) -> AspirationWeek {
        let perSource = AspirationRollup.contributionSources(of: aspiration)
            .map { (kind: $0.kind, sessions: context.bounds.current(in: $0.sessions)) }
        let sessions = perSource.flatMap(\.sessions)
        let id = stableID(of: aspiration)
        return AspirationWeek(
            id: id,
            title: aspiration.title,
            icon: aspiration.displayIcon,
            colorName: aspiration.colorName,
            totals: aspirationTotals(perSource),
            sessionCount: sessions.count,
            activeDays: activeDays(in: sessions, calendar: context.calendar),
            dailySeries: dailyValues(
                of: sessions, from: context.bounds.start, calendar: context.calendar
            ) { _ in 1 },
            intentions: intentionLines(of: aspiration, context: context),
            offersCheckIn: context.bounds.isCurrentWeek && !context.checkedInOwners.contains(id),
            narrowing: context.bounds.isCurrentWeek
                ? MeasureHealth.detectNarrowing(for: aspiration, now: context.now, calendar: context.calendar)
                : nil
        )
    }

    /// This week's effort merged into one total per unit, zero units dropped.
    static func aspirationTotals(
        _ perSource: [(kind: RollupBucket.Kind, sessions: [Session])]
    ) -> [UnitTotal] {
        let totals = perSource.map {
            UnitTotal(kind: $0.kind, value: AspirationRollup.magnitude(of: $0.kind, over: $0.sessions))
        }
        return AspirationRollup
            .mergeByUnit(totals, kind: \.kind) { UnitTotal(kind: $0.kind, value: $0.value + $1.value) }
            .filter { $0.value > 0 }
    }

    /// The aspiration's open intentions of the current calendar week, in
    /// creation order — and only on the live review: browsing earlier weeks
    /// carries no intention machinery.
    static func intentionLines(
        of aspiration: Aspiration,
        context: AspirationWeekContext
    ) -> [IntentionLine] {
        guard context.bounds.isCurrentWeek else { return [] }
        let id = stableID(of: aspiration)
        return context.intentions
            .filter { belongsOnCard($0, aspirationID: id, context: context) }
            .sorted { $0.createdAt < $1.createdAt }
            .map { intention in
                IntentionLine(
                    id: intention.stableID?.uuidString ?? intention.title,
                    title: intention.title,
                    progressText: IntentionProgress.compute(for: intention, calendar: context.calendar)?.text
                )
            }
    }

    /// Whether an intention renders as a line on this aspiration's card:
    /// open, living in the current calendar week, and owned by it.
    static func belongsOnCard(
        _ intention: Intention,
        aspirationID: String,
        context: AspirationWeekContext
    ) -> Bool {
        guard intention.isOpen,
              intention.isInCurrentWeek(now: context.now, calendar: context.calendar)
        else { return false }
        return intention.aspiration.map { stableID(of: $0) } == aspirationID
    }
}

// MARK: - Drill-in detail

extension WeeklyReview {
    /// One attachment's effort inside the reviewed week ("Reading — 1h 20m"),
    /// after the same de-dup as every other aspiration total.
    struct AspirationWeekSource: Identifiable {
        let id: String
        let name: String
        let isProject: Bool
        let text: String
    }

    /// The screen behind an aspiration's review card: the week itself, where
    /// the effort landed, and the period frame anchoring the day labels.
    /// Recomputed fresh on every render, never stored.
    struct AspirationWeekDetail {
        let week: AspirationWeek
        let sources: [AspirationWeekSource]
        /// Start of the oldest day in the period.
        let start: Date
        /// The latest moment covered: now for the current week, the final
        /// day for an earlier one.
        let end: Date
        let weeksBack: Int

        /// Offset into the period of the day with the most sessions, nil for
        /// a quiet week.
        var busiestDayOffset: Int? {
            guard let maxValue = week.dailySeries.max(), maxValue > 0 else { return nil }
            return week.dailySeries.firstIndex(of: maxValue)
        }

        /// The calendar day at the given offset into the period.
        func day(at offset: Int, calendar: Calendar = .current) -> Date {
            calendar.date(byAdding: .day, value: offset, to: start) ?? start
        }
    }

    /// Assembles one aspiration's week for the drill-in screen. Intention
    /// lines stay empty here — the screen reads the live models instead, so
    /// ticks and closures reflect immediately.
    static func aspirationWeekDetail(
        for aspiration: Aspiration,
        weeksBack: Int = 0,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> AspirationWeekDetail {
        let bounds = PeriodBounds(weeksBack: weeksBack, now: now, calendar: calendar)
        let context = AspirationWeekContext(
            bounds: bounds, now: now, calendar: calendar,
            intentions: [], closureOwners: [], checkedInOwners: []
        )
        return AspirationWeekDetail(
            week: weekData(of: aspiration, context: context),
            sources: weekSources(of: aspiration, bounds: bounds),
            start: bounds.start,
            end: bounds.displayEnd,
            weeksBack: weeksBack
        )
    }

    /// The per-attachment split of the week, quiet attachments dropped.
    private static func weekSources(
        of aspiration: Aspiration,
        bounds: PeriodBounds
    ) -> [AspirationWeekSource] {
        AspirationRollup.contributionSources(of: aspiration)
            .enumerated()
            .compactMap { index, source in
                let value = AspirationRollup.magnitude(
                    of: source.kind, over: bounds.current(in: source.sessions)
                )
                guard value > 0 else { return nil }
                return AspirationWeekSource(
                    id: "\(source.isProject ? "project" : "metric")-\(index)",
                    name: source.name,
                    isProject: source.isProject,
                    text: UnitTotal(kind: source.kind, value: value).text
                )
            }
    }
}
