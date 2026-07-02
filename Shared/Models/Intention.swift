import Foundation
#if canImport(SwiftData)
import SwiftData
#endif

// A small, week-scoped commitment attached to exactly one aspiration — the
// missing middle timescale between Today (the day) and an aspiration (the
// lifetime). It is born inside a calendar week, lives only for that week, and
// is closed at the next weekly review. Expiry is the feature: the app never
// computes completion rates, streaks, pace, or any cross-week aggregate over
// intention outcomes — history exists only as narrative.
//
// Mirrors the `#if canImport(SwiftData)` shape of `Aspiration` so the type
// also compiles in the Linux SwiftPM overlay, where it degrades to a plain
// class.
#if canImport(SwiftData)
@Model
#endif
final class Intention {
    #if canImport(SwiftData)
    #Unique<Intention>([\.stableID])
    #endif
    /// Stable identity (mirrors `Aspiration.stableID`); also what a renewed
    /// intention's `predecessorID` points back to.
    var stableID: UUID?
    /// The commitment, in the user's words.
    var title: String
    /// Raw `IntentionKind`, stored as the raw string so a store written by a
    /// newer app version with an unknown kind still opens.
    var kindRaw: String
    /// Raw `DerivedMode`; derived intentions only.
    var derivedModeRaw: String?
    /// Whether progress advances by distinct eligible days rather than raw
    /// counts ("one act of kindness each day").
    var perDay: Bool = false
    /// The weekly target; nil when `perDay` (implicitly once per day).
    var target: Double?
    /// Normalized start of the calendar week the intention lives in.
    var weekStart: Date
    /// Timestamped manual increments; counted intentions only.
    var tickDates: [Date] = []

    // Nullify both ways, mirroring the `Aspiration.metrics` pattern: deleting
    // the metric strands the intention ("source removed") rather than deleting
    // it, and deleting the intention never touches the metric.
    #if canImport(SwiftData)
    @Relationship(deleteRule: .nullify, inverse: \Metric.intentions)
    #endif
    var metric: Metric?

    /// The owning aspiration — required semantically (no standalone
    /// intentions, ever; see `make`). The cascade relationship is declared on
    /// `Aspiration.intentions`, a deliberate divergence from the aspiration's
    /// nullify-everything doctrine: an intention is meaningless without its
    /// why.
    var aspiration: Aspiration?

    /// Raw `IntentionOutcome`; nil while open, and nil forever on an
    /// intention closed by renewal — the numbers stood on their own.
    var outcomeRaw: String?
    /// When the intention was processed at a review or let go mid-week.
    var closedAt: Date?
    /// `stableID` of the prior week's renewal source, forming the chain a
    /// promotion offer is earned along.
    var predecessorID: UUID?
    /// Whether a promotion offer was declined somewhere along the chain;
    /// copied forward on renewal so the chain is never asked again.
    var promotionDismissed: Bool = false
    var createdAt: Date

    init(
        title: String,
        kind: IntentionKind,
        aspiration: Aspiration?,
        derivedMode: DerivedMode? = nil,
        metric: Metric? = nil,
        perDay: Bool = false,
        target: Double? = nil,
        weekStart: Date,
        createdAt: Date = .now
    ) {
        stableID = UUID()
        self.title = title
        kindRaw = kind.rawValue
        self.aspiration = aspiration
        derivedModeRaw = derivedMode?.rawValue
        self.metric = metric
        self.perDay = perDay
        self.target = target
        self.weekStart = weekStart
        self.createdAt = createdAt
    }
}

// MARK: - Typed accessors

extension Intention {
    /// The stored kind, reading an unknown raw value as `reflective` — the
    /// most inert kind, so foreign data degrades to a row with no machinery.
    var kind: IntentionKind {
        IntentionKind(rawValue: kindRaw) ?? .reflective
    }

    var derivedMode: DerivedMode? {
        derivedModeRaw.flatMap(DerivedMode.init(rawValue:))
    }

    var outcome: IntentionOutcome? {
        outcomeRaw.flatMap(IntentionOutcome.init(rawValue:))
    }

    /// Whether the intention still awaits its closure decision.
    var isOpen: Bool {
        closedAt == nil
    }

    /// A derived intention whose metric was deleted mid-week: progress is
    /// unavailable and only letting go remains.
    var isSourceRemoved: Bool {
        kind == .derived && metric == nil
    }
}

// MARK: - Week windowing

extension Intention {
    /// The calendar week the intention lives in — the same
    /// `dateInterval(of: .weekOfYear)` convention as `SessionStatistics` and
    /// `GoalPace`, so the review and the intention never disagree about what
    /// "this week" means.
    func weekInterval(calendar: Calendar = .current) -> DateInterval {
        calendar.dateInterval(of: .weekOfYear, for: weekStart)
            ?? DateInterval(start: weekStart, duration: 7 * 24 * 3600)
    }

    func isInCurrentWeek(now: Date = .now, calendar: Calendar = .current) -> Bool {
        weekStart == Self.weekStart(containing: now, calendar: calendar)
    }

    /// The normalized start of the calendar week containing `date`.
    static func weekStart(containing date: Date, calendar: Calendar = .current) -> Date {
        calendar.dateInterval(of: .weekOfYear, for: date)?.start
            ?? calendar.startOfDay(for: date)
    }
}

// MARK: - Ticks

extension Intention {
    /// Records one manual increment, refusing dates outside the intention's
    /// week — the tick window closes at the week boundary.
    @discardableResult
    func tick(at date: Date = .now, calendar: Calendar = .current) -> Bool {
        // Half-open, like every week window in the app: `DateInterval.contains`
        // would admit the next week's first midnight.
        let week = weekInterval(calendar: calendar)
        guard date >= week.start, date < week.end else { return false }
        tickDates.append(date)
        return true
    }

    /// Removes the most recent tick, but only if it is from today — earlier
    /// days are settled.
    @discardableResult
    func undoTick(now: Date = .now, calendar: Calendar = .current) -> Bool {
        guard let latest = tickDates.max(),
              calendar.isDate(latest, inSameDayAs: now),
              let index = tickDates.lastIndex(of: latest)
        else { return false }
        tickDates.remove(at: index)
        return true
    }

    func hasTick(on date: Date = .now, calendar: Calendar = .current) -> Bool {
        tickDates.contains { calendar.isDate($0, inSameDayAs: date) }
    }
}

// MARK: - Closure

extension Intention {
    /// Closes the intention with a verdict (or none, when closed by renewal).
    /// Closures are final; history rows may be deleted, never edited.
    func close(outcome: IntentionOutcome?, at date: Date = .now) {
        outcomeRaw = outcome?.rawValue
        closedAt = date
    }

    /// Releases the intention — mid-week or at the review. Distinct from
    /// deletion: the record stays, as a valid ending equal to done.
    func letGo(at date: Date = .now) {
        close(outcome: .letGo, at: date)
    }
}
