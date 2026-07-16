import Foundation
import Testing
@testable import lead_track
#if canImport(SwiftData)
import SwiftData
#endif

/// Week windowing: alignment with the `SessionStatistics` convention, DST
/// transition weeks, midnight bucketing, and the tick-window close.
struct IntentionWeekBoundaryTests {
    private let calendar = Calendar.current

    #if canImport(SwiftData)
    private let context: ModelContext

    init() throws {
        let container = try SharedModelContainer.create(inMemoryOnly: true)
        context = ModelContext(container)
    }
    #endif

    // MARK: - Fixtures

    /// A fixed-zone calendar so the DST cases are deterministic regardless of
    /// the machine's locale: Berlin observes DST, weeks start Monday.
    private var berlin: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin") ?? .current
        calendar.firstWeekday = 2
        return calendar
    }

    private func makeAspiration() -> Aspiration {
        let aspiration = Aspiration(title: "Vitality")
        #if canImport(SwiftData)
        context.insert(aspiration)
        #endif
        return aspiration
    }

    private func addSession(to metric: Metric, at start: Date) {
        let session = Session(metric: metric, startedAt: start, endedAt: start.addingTimeInterval(600))
        #if canImport(SwiftData)
        context.insert(session)
        #else
        metric.sessions.append(session)
        #endif
    }

    private func perDayCounted(createdAt: Date, calendar: Calendar) throws -> Intention {
        try Intention.make(
            title: "walk every day", kind: .counted, aspiration: makeAspiration(),
            perDay: true, createdAt: createdAt, calendar: calendar
        )
    }
}

// MARK: - Convention alignment

extension IntentionWeekBoundaryTests {
    /// The intention's week is the same `dateInterval(of: .weekOfYear)`
    /// window `SessionStatistics` totals with, half-open on both surfaces: a
    /// session at the week's first instant belongs, one at the next week's
    /// first midnight does not.
    @Test
    func weekAttributionMatchesSessionStatistics() throws {
        let metric = Metric(name: "Walking")
        #if canImport(SwiftData)
        context.insert(metric)
        #endif
        let week = try #require(calendar.dateInterval(of: .weekOfYear, for: .now))
        addSession(to: metric, at: week.start)
        addSession(to: metric, at: week.end)

        let intention = try Intention.make(
            title: "3 walks", kind: .derived, aspiration: makeAspiration(),
            derivedMode: .sessionCount, metric: metric, target: 3
        )
        let progress = IntentionProgress.compute(for: intention, calendar: calendar)

        #expect(intention.weekInterval(calendar: calendar) == week)
        #expect(progress?.value == 1)
        #expect(SessionStatistics.currentWeekTotal(from: metric.sessions) == 600)
    }
}

// MARK: - DST weeks

extension IntentionWeekBoundaryTests {
    @Test
    func springForwardWeekStillHasSevenEligibleDays() throws {
        // Berlin springs forward on 2026-03-29; its week (Mar 23–29) has a
        // 23-hour day but still seven `startOfDay` buckets.
        let calendar = berlin
        let created = try #require(calendar.date(from: DateComponents(year: 2026, month: 3, day: 23, hour: 10)))
        let intention = try perDayCounted(createdAt: created, calendar: calendar)

        let days = IntentionProgress.eligibleDays(of: intention, calendar: calendar)
        #expect(days.count == 7)
        #expect(intention.weekInterval(calendar: calendar).duration == 167 * 3600)
    }

    @Test
    func fallBackWeekStillHasSevenEligibleDays() throws {
        // Berlin falls back on 2026-10-25; a 25-hour day, still seven days.
        let calendar = berlin
        let created = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 19, hour: 10)))
        let intention = try perDayCounted(createdAt: created, calendar: calendar)

        let days = IntentionProgress.eligibleDays(of: intention, calendar: calendar)
        #expect(days.count == 7)
        #expect(intention.weekInterval(calendar: calendar).duration == 169 * 3600)
    }
}

// MARK: - Midnight bucketing

extension IntentionWeekBoundaryTests {
    @Test
    func ticksNearMidnightBucketByStartOfDay() throws {
        let calendar = berlin
        let created = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 1, hour: 9)))
        let intention = try perDayCounted(createdAt: created, calendar: calendar)
        let week = intention.weekInterval(calendar: calendar)
        let secondMidnight = try #require(calendar.date(byAdding: .day, value: 1, to: week.start))

        intention.tick(at: secondMidnight.addingTimeInterval(-60), calendar: calendar)
        intention.tick(at: secondMidnight, calendar: calendar)

        let progress = IntentionProgress.compute(for: intention, calendar: calendar)
        #expect(progress?.value == 2)
    }

    @Test
    func tickWindowClosesAtTheWeekBoundary() throws {
        let calendar = berlin
        let created = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 1, hour: 9)))
        let intention = try perDayCounted(createdAt: created, calendar: calendar)
        let week = intention.weekInterval(calendar: calendar)

        #expect(intention.tick(at: week.end.addingTimeInterval(-1), calendar: calendar))
        #expect(!intention.tick(at: week.end, calendar: calendar))
        #expect(!intention.tick(at: week.start.addingTimeInterval(-1), calendar: calendar))
        #expect(intention.tickDates.count == 1)
    }
}

// MARK: - Week close day

extension IntentionWeekBoundaryTests {
    /// Today's "held through Sunday" whisper names the week's last calendar
    /// day: the day before the next week's first midnight, matching the
    /// half-open convention of every week window in the app.
    @Test
    func weekLastDayIsTheDayBeforeTheNextWeekStarts() throws {
        let calendar = berlin
        let created = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 1, hour: 9)))
        let intention = try perDayCounted(createdAt: created, calendar: calendar)
        let week = intention.weekInterval(calendar: calendar)

        let lastDay = intention.weekLastDay(calendar: calendar)

        #expect(calendar.component(.weekday, from: lastDay) == 1)
        #expect(week.start <= lastDay && lastDay < week.end)
        #expect(calendar.isDate(lastDay, inSameDayAs: week.end.addingTimeInterval(-1)))
    }

    /// The fall-back week's 25-hour Sunday is still the last day — the
    /// computation rides the calendar, never 86 400-second arithmetic.
    @Test
    func weekLastDaySurvivesTheFallBackWeek() throws {
        let calendar = berlin
        let created = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 19, hour: 10)))
        let intention = try perDayCounted(createdAt: created, calendar: calendar)
        let week = intention.weekInterval(calendar: calendar)

        let lastDay = intention.weekLastDay(calendar: calendar)

        #expect(calendar.component(.weekday, from: lastDay) == 1)
        #expect(calendar.isDate(lastDay, inSameDayAs: week.end.addingTimeInterval(-1)))
    }
}

// MARK: - Undo

extension IntentionWeekBoundaryTests {
    @Test
    func undoRemovesTheMostRecentTickFromToday() throws {
        let intention = try Intention.make(
            title: "3 walks", kind: .counted, aspiration: makeAspiration(), target: 3
        )
        let now = Date.now
        intention.tick(at: now.addingTimeInterval(-1), calendar: calendar)
        intention.tick(at: now, calendar: calendar)

        #expect(intention.undoTick(now: now, calendar: calendar))
        #expect(intention.tickDates == [now.addingTimeInterval(-1)])
    }

    @Test
    func undoRefusesWhenTheLatestTickIsFromAnEarlierDay() throws {
        let lastWeek = try #require(calendar.date(byAdding: .weekOfYear, value: -1, to: .now))
        let intention = try Intention.make(
            title: "3 walks", kind: .counted, aspiration: makeAspiration(), target: 3, createdAt: lastWeek
        )
        intention.tick(at: lastWeek, calendar: calendar)

        #expect(!intention.undoTick())
        #expect(intention.tickDates.count == 1)
    }
}
