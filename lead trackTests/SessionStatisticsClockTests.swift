import Foundation
import Testing
@testable import lead_track

/// The `now:`-injection seams of `SessionStatistics`: every window, average,
/// and streak can be evaluated as of a fixed instant, so historical review
/// weeks and midnight boundaries are testable deterministically.
struct SessionStatisticsClockTests {
    private let calendar = Calendar.current

    private func makeDate(daysAgo: Int) -> Date {
        calendar.date(
            byAdding: .day, value: -daysAgo,
            to: calendar.startOfDay(for: .now)
        )!
    }

    private func makeTotal(daysAgo: Int, duration: TimeInterval) -> DailyTotal {
        DailyTotal(date: makeDate(daysAgo: daysAgo), duration: duration)
    }

    @Test
    func recentAverageAnchorsOnTheInjectedNow() {
        let totals = [
            makeTotal(daysAgo: 10, duration: 100),
            makeTotal(daysAgo: 11, duration: 200),
            makeTotal(daysAgo: 20, duration: 999)
        ]
        // As of 10 days ago, the trailing five days held 100 + 200.
        let avg = SessionStatistics.recentAverage(
            days: 5, from: totals, now: makeDate(daysAgo: 10)
        )
        #expect(avg == 60)
    }

    @Test
    func overallAverageSpansThroughTheInjectedNow() {
        let totals = [
            makeTotal(daysAgo: 4, duration: 100),
            makeTotal(daysAgo: 2, duration: 200)
        ]
        let avg = SessionStatistics.overallAverage(
            from: totals, now: makeDate(daysAgo: 2)
        )
        #expect(avg == 300.0 / 3.0)
    }

    @Test
    func todayTotalReadsTheInjectedDay() {
        let totals = [
            makeTotal(daysAgo: 3, duration: 300),
            makeTotal(daysAgo: 0, duration: 600)
        ]
        let total = SessionStatistics.todayTotal(
            from: totals, now: makeDate(daysAgo: 3)
        )
        #expect(total == 300)
    }

    @Test
    func currentStreakEvaluatesAsOfTheInjectedNow() {
        // The streak is dead today but was two days long back then (B-6).
        let totals = [
            makeTotal(daysAgo: 10, duration: 100),
            makeTotal(daysAgo: 11, duration: 100)
        ]
        #expect(SessionStatistics.currentStreak(from: totals) == 0)
        #expect(
            SessionStatistics.currentStreak(from: totals, now: makeDate(daysAgo: 10)) == 2
        )
    }
}
