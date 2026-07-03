import Foundation
import Testing
@testable import lead_track

private let calendar = Calendar.current

/// Noon today — far from both midnights, so tests never straddle a day
/// boundary while running.
private var noon: Date {
    calendar.startOfDay(for: .now).addingTimeInterval(12 * 3600)
}

private var today: Date {
    calendar.startOfDay(for: .now)
}

private func metric(
    type: MeasurementType = .duration,
    todayTotal: Double = 0,
    dailyGoal: Double? = nil,
    excludedWeekdays: [Int]? = nil,
    runningSince: Date? = nil
) -> WatchMetricSnapshot {
    WatchMetricSnapshot(
        id: UUID(),
        name: "Metric",
        measurementType: type,
        unit: nil,
        icon: "book",
        colorName: nil,
        runningSince: runningSince,
        todayTotal: todayTotal,
        dailyGoal: dailyGoal,
        excludedWeekdays: excludedWeekdays
    )
}

private func first(
    of snapshot: WatchSnapshot,
    at now: Date
) throws -> ComplicationMetricProgress {
    try #require(
        ComplicationProgress.metrics(in: snapshot, at: now, calendar: calendar).first
    )
}

// MARK: - Effective totals

struct ComplicationProgressTests {
    @Test
    func sameDaySnapshotKeepsTotals() throws {
        let snapshot = WatchSnapshot(
            metrics: [metric(todayTotal: 120, dailyGoal: 600)], day: today
        )

        let progress = try first(of: snapshot, at: noon)

        #expect(progress.todayTotal == 120)
        #expect(progress.percent == 20)
    }

    @Test
    func staleSnapshotZeroesTotals() throws {
        let yesterday = try #require(
            calendar.date(byAdding: .day, value: -1, to: today)
        )
        let snapshot = WatchSnapshot(
            metrics: [metric(todayTotal: 120, dailyGoal: 600)], day: yesterday
        )

        let progress = try first(of: snapshot, at: noon)

        #expect(progress.todayTotal == 0)
        #expect(progress.percent == 0)
    }

    @Test
    func snapshotWithoutDayStampIsTrusted() throws {
        let snapshot = WatchSnapshot(metrics: [metric(todayTotal: 120)])

        let progress = try first(of: snapshot, at: noon)

        #expect(progress.todayTotal == 120)
    }

    @Test
    func midnightEntryResetsTheDay() throws {
        let tomorrow = try #require(
            calendar.date(byAdding: .day, value: 1, to: today)
        )
        let snapshot = WatchSnapshot(
            metrics: [metric(todayTotal: 120, dailyGoal: 600)], day: today
        )

        let progress = try first(of: snapshot, at: tomorrow)

        #expect(progress.todayTotal == 0)
    }

    @Test
    func runningTimerStartedTodayCountsElapsed() throws {
        let snapshot = WatchSnapshot(
            metrics: [
                metric(
                    todayTotal: 100,
                    dailyGoal: 1400,
                    runningSince: noon.addingTimeInterval(-600)
                )
            ],
            day: today
        )

        let progress = try first(of: snapshot, at: noon)

        #expect(progress.todayTotal == 700)
        #expect(progress.isRunning)
        #expect(progress.percent == 50)
    }

    @Test
    func runningTimerStartedYesterdayDoesNotCount() throws {
        let yesterday = try #require(
            calendar.date(byAdding: .day, value: -1, to: today)
        )
        let snapshot = WatchSnapshot(
            metrics: [
                metric(
                    todayTotal: 300,
                    dailyGoal: 600,
                    runningSince: yesterday.addingTimeInterval(12 * 3600)
                )
            ],
            day: yesterday
        )

        let progress = try first(of: snapshot, at: noon)

        #expect(progress.todayTotal == 0)
        #expect(progress.isRunning)
    }
}

// MARK: - Fractions, goal lines & summary

struct ComplicationFractionTests {
    @Test
    func restDaySuspendsTheTarget() throws {
        let weekday = calendar.component(.weekday, from: noon)
        let snapshot = WatchSnapshot(
            metrics: [
                metric(todayTotal: 120, dailyGoal: 600, excludedWeekdays: [weekday])
            ],
            day: today
        )

        let progress = try first(of: snapshot, at: noon)

        #expect(progress.isRestDay)
        #expect(!progress.hasActiveTarget)
        #expect(progress.fraction == nil)
        #expect(progress.percent == nil)
        #expect(!progress.isMet)
    }

    @Test
    func binaryReadsZeroOrFull() throws {
        let done = WatchSnapshot(
            metrics: [metric(type: .binary, todayTotal: 1)], day: today
        )
        let pending = WatchSnapshot(
            metrics: [metric(type: .binary, todayTotal: 0)], day: today
        )

        let doneProgress = try first(of: done, at: noon)
        let pendingProgress = try first(of: pending, at: noon)

        #expect(doneProgress.hasDailyTarget)
        #expect(doneProgress.fraction == 1)
        #expect(doneProgress.isMet)
        #expect(pendingProgress.fraction == 0)
        #expect(!pendingProgress.isMet)
    }

    @Test
    func percentTruncatesAndClamps() throws {
        let almost = WatchSnapshot(
            metrics: [metric(todayTotal: 996, dailyGoal: 1000)], day: today
        )
        let over = WatchSnapshot(
            metrics: [metric(todayTotal: 2000, dailyGoal: 1000)], day: today
        )

        #expect(try first(of: almost, at: noon).percent == 99)
        let overProgress = try first(of: over, at: noon)
        #expect(overProgress.fraction == 1)
        #expect(overProgress.percent == 100)
        #expect(overProgress.isMet)
    }

    @Test
    func nonPositiveGoalYieldsNoFraction() throws {
        let snapshot = WatchSnapshot(
            metrics: [metric(todayTotal: 5, dailyGoal: 0)], day: today
        )

        let progress = try first(of: snapshot, at: noon)

        #expect(progress.fraction == nil)
        #expect(!progress.isMet)
    }

    @Test
    func metricWithoutGoalHasNoTarget() throws {
        let snapshot = WatchSnapshot(
            metrics: [metric(todayTotal: 5)], day: today
        )

        let progress = try first(of: snapshot, at: noon)

        #expect(!progress.hasDailyTarget)
        #expect(progress.fraction == nil)
    }

    @Test
    func goalLinesKeepSnapshotOrderAndCap() {
        let named: (String, Double?) -> WatchMetricSnapshot = { name, goal in
            WatchMetricSnapshot(
                id: UUID(),
                name: name,
                measurementType: .duration,
                unit: nil,
                icon: nil,
                colorName: nil,
                todayTotal: 0,
                dailyGoal: goal
            )
        }
        let snapshot = WatchSnapshot(
            metrics: [
                named("A", 600),
                named("B", nil),
                named("C", 600),
                named("D", 600),
                named("E", 600)
            ],
            day: today
        )

        let lines = ComplicationProgress.goalLines(
            in: snapshot, at: noon, calendar: calendar
        )

        #expect(lines.map(\.name) == ["A", "C", "D"])
    }

    @Test
    func dailySummaryCountsActiveTargetsAndMet() {
        let weekday = calendar.component(.weekday, from: noon)
        let snapshot = WatchSnapshot(
            metrics: [
                metric(todayTotal: 700, dailyGoal: 600),
                metric(todayTotal: 100, dailyGoal: 600),
                metric(type: .binary, todayTotal: 1),
                metric(todayTotal: 0, dailyGoal: 600, excludedWeekdays: [weekday]),
                metric(todayTotal: 50)
            ],
            day: today
        )

        let summary = ComplicationProgress.dailySummary(
            in: snapshot, at: noon, calendar: calendar
        )

        #expect(summary.met == 2)
        #expect(summary.total == 3)
        #expect(summary.hasGoals)
    }
}
