import Foundation
import Testing
@testable import lead_track
#if canImport(SwiftData)
import SwiftData
#endif

struct OversubscriptionInsightTests {
    private let calendar = Calendar.current

    #if canImport(SwiftData)
    /// Relationship arrays only sync through a context on Apple platforms;
    /// the Linux overlay compiles the models as plain classes instead.
    private let context: ModelContext

    init() throws {
        let container = try SharedModelContainer.create(inMemoryOnly: true)
        context = ModelContext(container)
    }
    #endif

    // MARK: - Fixtures

    /// Midnight `daysAgo` days back, so sessions never straddle `now`.
    private func day(_ daysAgo: Int) -> Date {
        calendar.date(
            byAdding: .day, value: -daysAgo,
            to: calendar.startOfDay(for: .now)
        )!
    }

    private var now: Date {
        day(0)
    }

    private func goalMetric(
        name: String = "Reading",
        type: MeasurementType = .duration,
        dailyGoal: TimeInterval? = 600
    ) -> Metric {
        let metric = Metric(name: name, measurementType: type)
        metric.dailyGoal = dailyGoal
        #if canImport(SwiftData)
        context.insert(metric)
        #endif
        return metric
    }

    private func log(_ value: Double, to metric: Metric, on day: Date) {
        let session = metric.measurementType == .duration
            ? Session(metric: metric, startedAt: day, endedAt: day.addingTimeInterval(value))
            : Session(metric: metric, startedAt: day, value: value)
        #if canImport(SwiftData)
        context.insert(session)
        #else
        metric.sessions.append(session)
        #endif
    }

    /// Runs the same daily amounts for each of the last three completed days.
    private func logEachDay(_ range: ClosedRange<Int>, _ body: (Date) -> Void) {
        for offset in range {
            body(day(offset))
        }
    }

    // MARK: - Guards

    @Test
    func singleGoalNeverRaisesTheCheckIn() {
        // One goal, worked on but never met — a plain shortfall, not a load
        // problem, so the check-in stays silent no matter the miss rate.
        let solo = goalMetric()
        logEachDay(1 ... 21) { log(300, to: solo, on: $0) }

        #expect(OversubscriptionInsight.checkIn(for: [solo], now: now) == nil)
    }

    @Test
    func tooFewActiveDaysStayQuiet() {
        let reading = goalMetric(name: "Reading")
        let writing = goalMetric(name: "Writing")
        // Only six active days, all short — below the pattern floor.
        logEachDay(1 ... 6) { day in
            log(600, to: reading, on: day)
            log(300, to: writing, on: day)
        }

        #expect(OversubscriptionInsight.checkIn(for: [reading, writing], now: now) == nil)
    }

    @Test
    func mostlyMetGoalsStayQuiet() {
        let reading = goalMetric(name: "Reading")
        let writing = goalMetric(name: "Writing")
        logEachDay(4 ... 21) { day in // both met
            log(600, to: reading, on: day)
            log(600, to: writing, on: day)
        }
        logEachDay(1 ... 3) { day in // three short days: 3/21 ≈ 14%
            log(600, to: reading, on: day)
            log(300, to: writing, on: day)
        }

        #expect(OversubscriptionInsight.checkIn(for: [reading, writing], now: now) == nil)
    }

    // MARK: - Threshold

    @Test
    func exactlyTwentyPercentStaysQuiet() {
        let reading = goalMetric(name: "Reading")
        let writing = goalMetric(name: "Writing")
        // Twenty active days (day 21 left idle), four short → exactly 20%.
        logEachDay(5 ... 20) { day in
            log(600, to: reading, on: day)
            log(600, to: writing, on: day)
        }
        logEachDay(1 ... 4) { day in
            log(600, to: reading, on: day)
            log(300, to: writing, on: day)
        }

        #expect(OversubscriptionInsight.checkIn(for: [reading, writing], now: now) == nil)
    }

    @Test
    func justOverTwentyPercentRaisesTheCheckIn() {
        let reading = goalMetric(name: "Reading")
        let writing = goalMetric(name: "Writing")
        // Twenty active days, five short → 25%.
        logEachDay(6 ... 20) { day in
            log(600, to: reading, on: day)
            log(600, to: writing, on: day)
        }
        logEachDay(1 ... 5) { day in
            log(600, to: reading, on: day)
            log(300, to: writing, on: day)
        }

        let checkIn = OversubscriptionInsight.checkIn(for: [reading, writing], now: now)
        #expect(checkIn?.goalCount == 2)
        #expect(checkIn?.missedDays == 5)
        #expect(checkIn?.activeDays == 20)
        #expect(checkIn?.allTogetherDays == 15)
    }

    // MARK: - Day accounting

    @Test
    func idleAndTodayDaysAreNeverMisses() {
        let reading = goalMetric(name: "Reading")
        let writing = goalMetric(name: "Writing")
        // A short pattern on eight days; everything else (including today) idle.
        logEachDay(1 ... 8) { day in
            log(600, to: reading, on: day)
            log(300, to: writing, on: day)
        }
        log(600, to: reading, on: now) // today — in progress, must not count

        let checkIn = OversubscriptionInsight.checkIn(for: [reading, writing], now: now)
        #expect(checkIn?.activeDays == 8)
        #expect(checkIn?.missedDays == 8)
    }

    @Test
    func binaryHabitNoShowCountsAsAShortfall() {
        let showUp = goalMetric(name: "Meditate", type: .binary, dailyGoal: nil)
        let reading = goalMetric(name: "Reading")
        // Reading engages the day, the habit is skipped: an active shortfall.
        logEachDay(1 ... 21) { day in log(600, to: reading, on: day) }

        let checkIn = OversubscriptionInsight.checkIn(for: [showUp, reading], now: now)
        #expect(checkIn?.goalCount == 2)
        #expect(checkIn?.activeDays == 21)
        #expect(checkIn?.missedDays == 21)
    }

    // MARK: - Review wiring

    @Test
    func liveReviewSurfacesItAndEarlierWeeksDoNot() {
        let reading = goalMetric(name: "Reading")
        let writing = goalMetric(name: "Writing")
        logEachDay(1 ... 21) { day in
            log(600, to: reading, on: day)
            log(300, to: writing, on: day)
        }

        let live = WeeklyReview.build(metrics: [reading, writing], now: now)
        let earlier = WeeklyReview.build(metrics: [reading, writing], weeksBack: 1, now: now)

        #expect(live.oversubscription != nil)
        #expect(earlier.oversubscription == nil)
    }

    // MARK: - Copy

    @Test
    func detailQuestionsTheLoadNotTheUser() {
        let checkIn = OversubscriptionInsight.CheckIn(
            goalCount: 2, missedDays: 15, activeDays: 18
        )

        #expect(checkIn.headline == "Maybe oversubscribed?")
        #expect(
            checkIn.detail == "Your 2 daily goals all landed together on only "
                + "3 of 18 active days these past three weeks. Would carrying "
                + "fewer at once serve the why better than reaching for them all?"
        )
    }
}
