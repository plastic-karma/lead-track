import Foundation
import Testing
@testable import lead_track

struct SessionStatisticsTests {
    private let calendar = Calendar.current

    private func makeTotal(
        daysAgo: Int,
        duration: TimeInterval
    ) -> DailyTotal {
        let date = calendar.date(
            byAdding: .day, value: -daysAgo,
            to: calendar.startOfDay(for: .now)
        )!
        return DailyTotal(date: date, duration: duration)
    }

    // MARK: - Daily Totals

    @Test
    func dailyTotalsGroupsByDay() {
        let today = Date.now
        let s1 = Session(startedAt: today, endedAt: today.addingTimeInterval(60))
        let s2 = Session(startedAt: today, endedAt: today.addingTimeInterval(120))
        let totals = SessionStatistics.dailyTotals(from: [s1, s2])
        #expect(totals.count == 1)
        #expect(totals[0].duration == 180)
    }

    @Test
    func dailyTotalsExcludesRunningSessions() {
        let running = Session(startedAt: .now)
        let totals = SessionStatistics.dailyTotals(from: [running])
        #expect(totals.isEmpty)
    }

    // MARK: - Current Streak

    @Test
    func currentStreakConsecutiveDays() {
        let totals = [
            makeTotal(daysAgo: 0, duration: 100),
            makeTotal(daysAgo: 1, duration: 100),
            makeTotal(daysAgo: 2, duration: 100)
        ]
        #expect(SessionStatistics.currentStreak(from: totals) == 3)
    }

    @Test
    func currentStreakBreaksOnGap() {
        let totals = [
            makeTotal(daysAgo: 0, duration: 100),
            makeTotal(daysAgo: 1, duration: 100),
            makeTotal(daysAgo: 3, duration: 100)
        ]
        #expect(SessionStatistics.currentStreak(from: totals) == 2)
    }

    @Test
    func currentStreakZeroWhenNoRecentActivity() {
        let totals = [
            makeTotal(daysAgo: 5, duration: 100)
        ]
        #expect(SessionStatistics.currentStreak(from: totals) == 0)
    }

    @Test
    func currentStreakCountsYesterdayIfNotToday() {
        let totals = [
            makeTotal(daysAgo: 1, duration: 100),
            makeTotal(daysAgo: 2, duration: 100)
        ]
        #expect(SessionStatistics.currentStreak(from: totals) == 2)
    }

    // MARK: - Longest Streak

    @Test
    func longestStreakFindsMaxRun() {
        let totals = [
            makeTotal(daysAgo: 0, duration: 100),
            makeTotal(daysAgo: 1, duration: 100),
            makeTotal(daysAgo: 5, duration: 100),
            makeTotal(daysAgo: 6, duration: 100),
            makeTotal(daysAgo: 7, duration: 100)
        ]
        #expect(SessionStatistics.longestStreak(from: totals) == 3)
    }

    @Test
    func longestStreakReturnsZeroWhenEmpty() {
        #expect(SessionStatistics.longestStreak(from: []) == 0)
    }

    @Test
    func longestStreakSingleDay() {
        let totals = [makeTotal(daysAgo: 3, duration: 100)]
        #expect(SessionStatistics.longestStreak(from: totals) == 1)
    }

    // MARK: - Today Total

    @Test
    func todayTotalReturnsCurrentDay() {
        let totals = [
            makeTotal(daysAgo: 0, duration: 300),
            makeTotal(daysAgo: 1, duration: 600)
        ]
        #expect(SessionStatistics.todayTotal(from: totals) == 300)
    }

    @Test
    func todayTotalReturnsZeroWhenNoToday() {
        let totals = [makeTotal(daysAgo: 1, duration: 600)]
        #expect(SessionStatistics.todayTotal(from: totals) == 0)
    }

    // MARK: - Recent Average

    @Test
    func recentAverageDividesByRequestedDays() {
        let totals = [
            makeTotal(daysAgo: 0, duration: 100),
            makeTotal(daysAgo: 1, duration: 200)
        ]
        let avg = SessionStatistics.recentAverage(days: 5, from: totals)
        #expect(avg == 60)
    }

    // MARK: - Overall Average

    @Test
    func overallAverageSpansFullRange() {
        let totals = [
            makeTotal(daysAgo: 4, duration: 100),
            makeTotal(daysAgo: 0, duration: 100)
        ]
        let avg = SessionStatistics.overallAverage(from: totals)
        #expect(avg == 200.0 / 5.0)
    }
}
