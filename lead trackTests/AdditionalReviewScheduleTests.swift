import Foundation
import Testing
@testable import lead_track

struct AdditionalReviewStoreTests {
    @Test
    func roundTripsArbitraryDefinitionsAndPreservesOrder() {
        let reviews = [
            AdditionalReview(name: "Month", cycle: .monthly),
            AdditionalReview(name: "Quarter", cycle: .quarterly),
            AdditionalReview(name: "Ten Days", cycle: .custom, customInterval: 10)
        ]
        let decoded = AdditionalReviewStore.decode(AdditionalReviewStore.encode(reviews))
        #expect(decoded == reviews)
    }

    @Test
    func updateAndRemovalTargetOnlyTheMatchingDefinition() {
        let first = AdditionalReview(name: "Month", cycle: .monthly)
        let second = AdditionalReview(name: "Quarter", cycle: .quarterly)
        var changed = first
        changed.name = "Month End"
        let updated = AdditionalReviewStore.upserting(changed, in: [first, second])
        #expect(updated == [changed, second])
        #expect(AdditionalReviewStore.removing(id: first.id, from: updated) == [second])
    }

    @Test
    func savesTheCollectionUnderOneStableDefaultsKey() throws {
        let suite = "additional-review-tests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let reviews = [AdditionalReview(name: "Year", cycle: .yearly)]
        AdditionalReviewStore.save(reviews, in: defaults)
        #expect(AdditionalReviewStore.key == "additionalReviews")
        #expect(AdditionalReviewStore.reviews(in: defaults) == reviews)
    }

    @Test
    func migratesWithdrawnCustomScheduleWithoutChangingWeeklySettings() throws {
        let suite = "additional-review-migration-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("custom", forKey: "weeklyReviewCycle")
        defaults.set("days", forKey: "weeklyReviewCustomUnit")
        defaults.set(14, forKey: "weeklyReviewCustomInterval")
        defaults.set(5, forKey: WeeklyReviewSettings.dayKey)
        defaults.set(17, forKey: WeeklyReviewSettings.hourKey)
        defaults.set(30, forKey: WeeklyReviewSettings.minuteKey)

        let reviews = AdditionalReviewStore.reviews(in: defaults)

        #expect(reviews.count == 1)
        #expect(reviews.first?.name == "14-Day Review")
        #expect(reviews.first?.customInterval == 14)
        #expect(reviews.first?.hour == 17)
        #expect(WeeklyReviewSettings.day(in: defaults) == 5)
        #expect(defaults.string(forKey: "weeklyReviewCycle") == nil)
    }
}

struct AdditionalReviewScheduleTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? calendar.timeZone
        return calendar
    }

    @Test
    func tenDayReviewTotalsTheCompletedTenDaysAndNotifiesAtTheNextBoundary() throws {
        let anchor = try date(year: 2026, month: 8, day: 9)
        let now = try date(year: 2026, month: 8, day: 9, hour: 12)
        let review = customReview(interval: 10, unit: .days, anchor: anchor)
        let period = AdditionalReviewSchedule.period(for: review, now: now, calendar: calendar)
        let expectedPeriod = try DateInterval(
            start: date(year: 2026, month: 7, day: 30),
            end: anchor
        )
        let expectedNext = try date(year: 2026, month: 8, day: 19, hour: 9)
        #expect(period == expectedPeriod)
        #expect(AdditionalReviewSchedule.nextReviewDate(
            for: review, after: now, calendar: calendar
        ) == expectedNext)
    }

    @Test
    func twoWeeksIsAFourteenDayCustomReview() throws {
        let anchor = try date(year: 2026, month: 8, day: 9)
        let now = try date(year: 2026, month: 8, day: 10)
        let review = customReview(interval: 14, unit: .days, anchor: anchor)
        let next = AdditionalReviewSchedule.nextReviewDate(
            for: review, after: now, calendar: calendar
        )
        let expected = try date(year: 2026, month: 8, day: 23, hour: 9)
        #expect(next == expected)
    }

    @Test
    func customMonthsUseFirstOfMonthBoundaries() throws {
        let anchor = try date(year: 2026, month: 8, day: 9)
        let now = try date(year: 2026, month: 8, day: 20)
        let review = customReview(interval: 2, unit: .months, anchor: anchor)
        let period = AdditionalReviewSchedule.period(for: review, now: now, calendar: calendar)
        let expectedPeriod = try DateInterval(
            start: date(year: 2026, month: 6, day: 1),
            end: date(year: 2026, month: 8, day: 1)
        )
        let expectedNext = try date(year: 2026, month: 10, day: 1, hour: 9)
        #expect(period == expectedPeriod)
        #expect(AdditionalReviewSchedule.nextReviewDate(
            for: review, after: now, calendar: calendar
        ) == expectedNext)
    }

    @Test
    func presetsUseCompletedCalendarPeriods() throws {
        let now = try date(year: 2026, month: 8, day: 9, hour: 12)
        try assertPeriod(
            .monthly,
            now: now,
            expected: DateInterval(
                start: date(year: 2026, month: 7, day: 1),
                end: date(year: 2026, month: 8, day: 1)
            ),
            next: date(year: 2026, month: 9, day: 1, hour: 9)
        )
        try assertPeriod(
            .quarterly,
            now: now,
            expected: DateInterval(
                start: date(year: 2026, month: 4, day: 1),
                end: date(year: 2026, month: 7, day: 1)
            ),
            next: date(year: 2026, month: 10, day: 1, hour: 9)
        )
        try assertPeriod(
            .yearly,
            now: now,
            expected: DateInterval(
                start: date(year: 2025, month: 1, day: 1),
                end: date(year: 2026, month: 1, day: 1)
            ),
            next: date(year: 2027, month: 1, day: 1, hour: 9)
        )
    }

    @Test
    func presetBoundaryNotifiesThatDayWhenItsTimeHasNotPassed() throws {
        let now = try date(year: 2026, month: 9, day: 1, hour: 8)
        let review = AdditionalReview(name: "Month", cycle: .monthly)
        let next = AdditionalReviewSchedule.nextReviewDate(
            for: review, after: now, calendar: calendar
        )
        let expected = try date(year: 2026, month: 9, day: 1, hour: 9)
        #expect(next == expected)
    }

    private func customReview(
        interval: Int,
        unit: AdditionalReviewCycleUnit,
        anchor: Date
    ) -> AdditionalReview {
        AdditionalReview(
            name: "Custom", cycle: .custom,
            customUnit: unit, customInterval: interval, anchor: anchor
        )
    }

    private func assertPeriod(
        _ cycle: AdditionalReviewCycleKind,
        now: Date,
        expected: DateInterval,
        next: Date
    ) {
        let review = AdditionalReview(name: "Preset", cycle: cycle)
        #expect(AdditionalReviewSchedule.period(for: review, now: now, calendar: calendar)
            == expected)
        #expect(AdditionalReviewSchedule.nextReviewDate(for: review, after: now, calendar: calendar)
            == next)
    }

    private func date(
        year: Int,
        month: Int,
        day: Int,
        hour: Int = 0
    ) throws -> Date {
        try #require(calendar.date(from: DateComponents(
            year: year, month: month, day: day, hour: hour
        )))
    }
}
