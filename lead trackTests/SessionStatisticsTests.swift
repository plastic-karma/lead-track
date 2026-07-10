import Foundation
import Testing
@testable import lead_track

struct SessionStatisticsTests {
    private let calendar = Calendar.current

    private func makeTotal(
        daysAgo: Int,
        duration: TimeInterval,
        sessionCount: Int = 0
    ) -> DailyTotal {
        let date = calendar.date(
            byAdding: .day, value: -daysAgo,
            to: calendar.startOfDay(for: .now)
        )!
        return DailyTotal(
            date: date,
            duration: duration,
            sessionCount: sessionCount
        )
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

    // MARK: - Windowed Totals

    @Test
    func windowedTotalMatchesLastSevenDays() {
        let totals = [
            makeTotal(daysAgo: 0, duration: 100),
            makeTotal(daysAgo: 6, duration: 50),
            makeTotal(daysAgo: 7, duration: 25)
        ]
        #expect(
            SessionStatistics.windowedTotal(days: 7, from: totals)
                == SessionStatistics.lastSevenDaysTotal(from: totals)
        )
        #expect(SessionStatistics.windowedTotal(days: 7, from: totals) == 150)
    }

    @Test
    func windowedTotalCoversTodayPlusPriorDays() {
        let totals = [
            makeTotal(daysAgo: 0, duration: 100),
            makeTotal(daysAgo: 29, duration: 50),
            makeTotal(daysAgo: 30, duration: 25)
        ]
        #expect(SessionStatistics.windowedTotal(days: 30, from: totals) == 150)
    }

    @Test
    func windowedSessionCountSumsWithinWindow() {
        let totals = [
            makeTotal(daysAgo: 0, duration: 100, sessionCount: 2),
            makeTotal(daysAgo: 29, duration: 50, sessionCount: 1),
            makeTotal(daysAgo: 35, duration: 25, sessionCount: 5)
        ]
        #expect(SessionStatistics.windowedSessionCount(days: 30, from: totals) == 3)
    }

    // MARK: - Trailing Daily Series

    @Test
    func trailingDailySeriesZeroFillsMissingDays() {
        let totals = [
            makeTotal(daysAgo: 0, duration: 300),
            makeTotal(daysAgo: 2, duration: 100)
        ]
        let series = SessionStatistics.trailingDailySeries(
            days: 7, from: totals
        )
        #expect(series == [0, 0, 0, 0, 100, 0, 300])
    }

    @Test
    func trailingDailySeriesIgnoresDaysOutsideWindow() {
        let totals = [
            makeTotal(daysAgo: 7, duration: 500),
            makeTotal(daysAgo: 1, duration: 200)
        ]
        let series = SessionStatistics.trailingDailySeries(
            days: 7, from: totals
        )
        #expect(series == [0, 0, 0, 0, 0, 200, 0])
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

    // MARK: - Session Counts

    @Test
    func dailyTotalsCountsSessionsPerDay() {
        let today = Date.now
        let s1 = Session(startedAt: today, endedAt: today.addingTimeInterval(60))
        let s2 = Session(startedAt: today, endedAt: today.addingTimeInterval(120))
        let totals = SessionStatistics.dailyTotals(from: [s1, s2])
        #expect(totals[0].sessionCount == 2)
    }

    @Test
    func totalSessionsSumsAcrossDays() {
        let totals = [
            makeTotal(daysAgo: 0, duration: 100, sessionCount: 2),
            makeTotal(daysAgo: 1, duration: 100, sessionCount: 3)
        ]
        #expect(SessionStatistics.totalSessions(from: totals) == 5)
    }

    @Test
    func averageSessionsPerDaySpansFullRange() {
        let totals = [
            makeTotal(daysAgo: 4, duration: 100, sessionCount: 2),
            makeTotal(daysAgo: 0, duration: 100, sessionCount: 3)
        ]
        let avg = SessionStatistics.averageSessionsPerDay(from: totals)
        #expect(avg == 5.0 / 5.0)
    }

    @Test
    func recentAverageSessionsPerDayDividesByRequestedDays() {
        let totals = [
            makeTotal(daysAgo: 0, duration: 100, sessionCount: 2),
            makeTotal(daysAgo: 1, duration: 100, sessionCount: 3)
        ]
        let avg = SessionStatistics.recentAverageSessionsPerDay(
            days: 5, from: totals
        )
        #expect(avg == 5.0 / 5.0)
    }

    @Test
    func averageSessionLengthDividesTotalBySessions() {
        let totals = [
            makeTotal(daysAgo: 0, duration: 300, sessionCount: 2),
            makeTotal(daysAgo: 1, duration: 200, sessionCount: 3)
        ]
        let avg = SessionStatistics.averageSessionLength(from: totals)
        #expect(avg == 100)
    }

    @Test
    func averageSessionLengthZeroWhenNoSessions() {
        #expect(SessionStatistics.averageSessionLength(from: []) == 0)
    }

    @Test
    func recentAverageSessionLengthExcludesOlderDays() {
        let totals = [
            makeTotal(daysAgo: 0, duration: 200, sessionCount: 2),
            makeTotal(daysAgo: 10, duration: 500, sessionCount: 5)
        ]
        let avg = SessionStatistics.recentAverageSessionLength(
            days: 5, from: totals
        )
        #expect(avg == 100)
    }

    // MARK: - Streak Rest Days

    private func weekday(daysAgo: Int) -> Int {
        let date = calendar.date(
            byAdding: .day, value: -daysAgo,
            to: calendar.startOfDay(for: .now)
        )!
        return calendar.component(.weekday, from: date)
    }

    @Test
    func excludedWeekdayBridgesStreakGap() {
        let totals = [
            makeTotal(daysAgo: 0, duration: 100),
            makeTotal(daysAgo: 2, duration: 100)
        ]
        let streak = SessionStatistics.currentStreak(
            from: totals, excludedWeekdays: [weekday(daysAgo: 1)]
        )
        #expect(streak == 2)
    }

    @Test
    func unrelatedExclusionStillBreaksStreak() {
        let totals = [
            makeTotal(daysAgo: 0, duration: 100),
            makeTotal(daysAgo: 2, duration: 100)
        ]
        let streak = SessionStatistics.currentStreak(
            from: totals, excludedWeekdays: [weekday(daysAgo: 0)]
        )
        #expect(streak == 1)
    }

    @Test
    func restDayTodayKeepsStreakAlive() {
        let totals = [
            makeTotal(daysAgo: 1, duration: 100),
            makeTotal(daysAgo: 2, duration: 100)
        ]
        let streak = SessionStatistics.currentStreak(
            from: totals, excludedWeekdays: [weekday(daysAgo: 0)]
        )
        #expect(streak == 2)
    }

    @Test
    func allWeekdaysExcludedYieldsNoStreak() {
        let totals = [makeTotal(daysAgo: 0, duration: 100)]
        let streak = SessionStatistics.currentStreak(
            from: totals, excludedWeekdays: Set(1 ... 7)
        )
        #expect(streak == 0)
    }

    @Test
    func longestStreakBridgesExcludedDay() {
        let totals = [
            makeTotal(daysAgo: 0, duration: 100),
            makeTotal(daysAgo: 2, duration: 100)
        ]
        let streak = SessionStatistics.longestStreak(
            from: totals, excludedWeekdays: [weekday(daysAgo: 1)]
        )
        #expect(streak == 2)
    }

    // MARK: - Trend Series

    private func makeDate(daysAgo: Int) -> Date {
        calendar.date(
            byAdding: .day, value: -daysAgo,
            to: calendar.startOfDay(for: .now)
        )!
    }

    @Test
    func weeklyTotalsConservesDuration() {
        let totals = [
            makeTotal(daysAgo: 0, duration: 100, sessionCount: 1),
            makeTotal(daysAgo: 1, duration: 200, sessionCount: 2),
            makeTotal(daysAgo: 8, duration: 300, sessionCount: 3)
        ]
        let weeks = SessionStatistics.weeklyTotals(from: totals, since: makeDate(daysAgo: 30))
        let total = weeks.reduce(0) { $0 + $1.duration }
        #expect(total == 600)
    }

    @Test
    func weeklyTotalsRespectsCutoff() {
        let totals = [
            makeTotal(daysAgo: 0, duration: 100),
            makeTotal(daysAgo: 20, duration: 999)
        ]
        let weeks = SessionStatistics.weeklyTotals(from: totals, since: makeDate(daysAgo: 3))
        let total = weeks.reduce(0) { $0 + $1.duration }
        #expect(total == 100)
    }

    @Test
    func weeklyTotalsBucketsAreWeekStarts() {
        let totals = [makeTotal(daysAgo: 0, duration: 100)]
        let weeks = SessionStatistics.weeklyTotals(from: totals, since: makeDate(daysAgo: 7))
        for week in weeks {
            let start = calendar.dateInterval(of: .weekOfYear, for: week.date)?.start
            #expect(start == week.date)
        }
    }

    @Test
    func movingAverageDividesTrailingWindow() {
        let totals = [makeTotal(daysAgo: 0, duration: 700)]
        let avg = SessionStatistics.movingAverage(days: 7, from: totals, since: makeDate(daysAgo: 0))
        #expect(avg.count == 1)
        #expect(avg[0].duration == 100)
    }

    @Test
    func movingAverageSmoothsAcrossDays() {
        let totals = (0 ... 6).map { makeTotal(daysAgo: $0, duration: 70) }
        let avg = SessionStatistics.movingAverage(days: 7, from: totals, since: makeDate(daysAgo: 6))
        #expect(avg.count == 7)
        #expect(avg[0].duration == 10)
        #expect(avg[6].duration == 70)
    }
}

// MARK: - Day Grouping

struct SessionDayGroupingTests {
    private let calendar = Calendar.current

    private func makeDate(daysAgo: Int, hour: Int = 9) -> Date {
        let day = calendar.date(
            byAdding: .day, value: -daysAgo,
            to: calendar.startOfDay(for: .now)
        ) ?? .now
        return day.addingTimeInterval(TimeInterval(hour * 3600))
    }

    @Test
    func groupsSessionsByCalendarDay() {
        let sessions = [
            Session(startedAt: makeDate(daysAgo: 0, hour: 10)),
            Session(startedAt: makeDate(daysAgo: 0, hour: 8)),
            Session(startedAt: makeDate(daysAgo: 2))
        ]
        let groups = SessionDayGrouping.group(sessions)
        #expect(groups.count == 2)
        #expect(groups.first?.sessions.count == 2)
        #expect(groups.last?.sessions.count == 1)
    }

    @Test
    func groupsAreOrderedNewestFirst() throws {
        let sessions = [
            Session(startedAt: makeDate(daysAgo: 3)),
            Session(startedAt: makeDate(daysAgo: 1))
        ]
        let groups = SessionDayGrouping.group(sessions)
        let first = try #require(groups.first)
        let last = try #require(groups.last)
        #expect(first.day > last.day)
    }

    @Test
    func labelsTodayAndYesterday() {
        let now = Date.now
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now) ?? now
        #expect(SessionDayGrouping.label(for: now, relativeTo: now) == "Today")
        #expect(SessionDayGrouping.label(for: yesterday, relativeTo: now) == "Yesterday")
    }

    @Test
    func labelsOlderDaysWithTheirDate() {
        let now = Date.now
        let older = calendar.date(byAdding: .day, value: -10, to: now) ?? now
        let label = SessionDayGrouping.label(for: older, relativeTo: now)
        #expect(label != "Today")
        #expect(label != "Yesterday")
        // Render the expected day number through the same locale-aware
        // FormatStyle the source uses, so the assertion holds on hosts
        // whose locale writes dates with non-Western digits.
        #expect(label.contains(older.formatted(.dateTime.day())))
    }
}
