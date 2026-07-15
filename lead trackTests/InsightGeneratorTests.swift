import Foundation
import Testing
@testable import lead_track
#if canImport(SwiftData)
import SwiftData
#endif

/// Detector-level coverage for `InsightGenerator.generate`: each threshold at
/// and just below its floor, the strict-majority tie rules, the category cap,
/// and the half-open window boundaries. The week under test is
/// `[day(7), day(0))` compared against `[day(14), day(7))`.
struct InsightGeneratorTests {
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

    /// Midnight `daysAgo` days back, so sessions never straddle the window.
    private func day(_ daysAgo: Int) -> Date {
        calendar.date(
            byAdding: .day, value: -daysAgo,
            to: calendar.startOfDay(for: .now)
        )!
    }

    /// `daysAgo` days back at the given wall-clock hour.
    private func hour(_ hour: Int, daysAgo: Int) -> Date {
        calendar.date(byAdding: .hour, value: hour, to: day(daysAgo))!
    }

    private func makeMetric(
        type: MeasurementType = .duration,
        dailyGoal: TimeInterval? = nil
    ) -> Metric {
        let metric = Metric(name: "Reading", measurementType: type)
        metric.dailyGoal = dailyGoal
        #if canImport(SwiftData)
        context.insert(metric)
        #endif
        return metric
    }

    private func register(_ session: Session, with metric: Metric) {
        #if canImport(SwiftData)
        context.insert(session)
        #else
        metric.sessions.append(session)
        #endif
    }

    private func addDuration(
        _ seconds: TimeInterval,
        to metric: Metric,
        at start: Date
    ) {
        register(
            Session(metric: metric, startedAt: start, endedAt: start.addingTimeInterval(seconds)),
            with: metric
        )
    }

    private func generate(for metric: Metric) -> [Insight] {
        InsightGenerator.generate(
            for: metric,
            currentStart: day(7),
            previousStart: day(14),
            end: day(0)
        )
    }

    // MARK: - Window boundaries

    @Test
    func windowIncludesItsStartAndExcludesItsEnd() {
        let metric = makeMetric()
        addDuration(300, to: metric, at: day(8))
        addDuration(300, to: metric, at: day(9))
        addDuration(600, to: metric, at: day(7)) // exactly currentStart: current
        addDuration(600, to: metric, at: hour(13, daysAgo: 3))
        addDuration(2400, to: metric, at: day(0)) // exactly end: dropped
        addDuration(999, to: metric, at: day(20)) // before previousStart: dropped

        let insights = generate(for: metric)

        #expect(insights.contains(.volumeChange(
            measurementType: .duration, unit: nil,
            currentTotal: 1200, previousTotal: 600,
            currentCount: 2, previousCount: 2
        )))
    }

    @Test
    func runningSessionsNeverCount() {
        let metric = makeMetric()
        addDuration(300, to: metric, at: day(8))
        addDuration(300, to: metric, at: day(9))
        addDuration(600, to: metric, at: hour(9, daysAgo: 5))
        addDuration(600, to: metric, at: hour(13, daysAgo: 3))
        register(Session(metric: metric, startedAt: day(2)), with: metric)

        let insights = generate(for: metric)

        #expect(insights.contains(.volumeChange(
            measurementType: .duration, unit: nil,
            currentTotal: 1200, previousTotal: 600,
            currentCount: 2, previousCount: 2
        )))
    }

    // MARK: - Time-of-day mode

    @Test
    func timeOfDayModeFiresOnADominantWindow() {
        let metric = makeMetric()
        addDuration(600, to: metric, at: hour(9, daysAgo: 1))
        addDuration(600, to: metric, at: hour(9, daysAgo: 2))
        addDuration(600, to: metric, at: hour(9, daysAgo: 3))
        addDuration(600, to: metric, at: hour(18, daysAgo: 4))

        let insights = generate(for: metric)

        #expect(insights.contains(
            .timeOfDayMode(bucket: .morning, ratio: 0.75, sessionCount: 3)
        ))
    }

    @Test
    func timeOfDayModeNeedsFourSessions() {
        let metric = makeMetric()
        addDuration(600, to: metric, at: hour(9, daysAgo: 1))
        addDuration(600, to: metric, at: hour(9, daysAgo: 2))
        addDuration(600, to: metric, at: hour(9, daysAgo: 3))

        let insights = generate(for: metric)

        #expect(!insights.contains { $0.category == .distribution })
    }

    @Test
    func exactHalfIsNotATimeOfDayMode() {
        // 2 morning, 1 afternoon, 1 evening: the top bucket is unique but
        // holds exactly half — "mostly" requires a strict majority.
        let metric = makeMetric()
        addDuration(600, to: metric, at: hour(9, daysAgo: 1))
        addDuration(600, to: metric, at: hour(9, daysAgo: 2))
        addDuration(600, to: metric, at: hour(14, daysAgo: 3))
        addDuration(600, to: metric, at: hour(18, daysAgo: 4))

        let insights = generate(for: metric)

        #expect(!insights.contains { $0.category == .distribution })
    }

    @Test
    func timeOfDayTieStaysSilent() {
        // 2 morning vs 2 evening once flipped between "morning thing" and
        // "evening thing" per launch; a tied week has no mode.
        let metric = makeMetric()
        addDuration(600, to: metric, at: hour(9, daysAgo: 1))
        addDuration(600, to: metric, at: hour(9, daysAgo: 2))
        addDuration(600, to: metric, at: hour(18, daysAgo: 3))
        addDuration(600, to: metric, at: hour(18, daysAgo: 4))

        let insights = generate(for: metric)

        #expect(!insights.contains { $0.category == .distribution })
    }

    // MARK: - Day-of-week mode

    @Test
    func dayOfWeekModeFiresOnADominantDay() {
        // Two of four sessions on one day (0.5 > 0.4), times spread across
        // four buckets so the time-of-day detector stays quiet.
        let metric = makeMetric()
        addDuration(600, to: metric, at: hour(9, daysAgo: 2))
        addDuration(600, to: metric, at: hour(15, daysAgo: 2))
        addDuration(600, to: metric, at: hour(18, daysAgo: 3))
        addDuration(600, to: metric, at: hour(22, daysAgo: 4))

        let insights = generate(for: metric)

        let weekday = calendar.component(.weekday, from: day(2))
        #expect(insights.contains(
            .dayOfWeekMode(weekday: weekday, ratio: 0.5, sessionCount: 2)
        ))
    }

    @Test
    func dayOfWeekTieStaysSilentAndTimeOfDayTakesTheSlot() {
        // 2 + 2 sessions across two days is no day mode; with that tie
        // silent, the all-morning time-of-day insight wins the slot instead.
        let metric = makeMetric()
        addDuration(600, to: metric, at: hour(8, daysAgo: 2))
        addDuration(600, to: metric, at: hour(9, daysAgo: 2))
        addDuration(600, to: metric, at: hour(8, daysAgo: 3))
        addDuration(600, to: metric, at: hour(9, daysAgo: 3))

        let insights = generate(for: metric)

        #expect(insights.contains(
            .timeOfDayMode(bucket: .morning, ratio: 1.0, sessionCount: 4)
        ))
    }

    @Test
    func distributionCapKeepsTheFirstDetector() {
        // All four sessions in one morning: both distribution detectors
        // fire, the day-of-week one is collected first and wins the cap.
        let metric = makeMetric()
        for _ in 0 ..< 4 {
            addDuration(600, to: metric, at: hour(9, daysAgo: 2))
        }

        let insights = generate(for: metric)

        let weekday = calendar.component(.weekday, from: day(2))
        #expect(insights.count(where: { $0.category == .distribution }) == 1)
        #expect(insights.contains(
            .dayOfWeekMode(weekday: weekday, ratio: 1.0, sessionCount: 4)
        ))
    }

    // MARK: - Volume change

    @Test
    func binaryMetricsNeverGetAVolumeInsight() {
        let metric = makeMetric(type: .binary)
        register(Session(metric: metric, startedAt: day(8), value: 1), with: metric)
        register(Session(metric: metric, startedAt: day(9), value: 1), with: metric)
        for daysAgo in 1 ... 4 {
            register(Session(metric: metric, startedAt: day(daysAgo), value: 1), with: metric)
        }

        let insights = generate(for: metric)

        #expect(!insights.contains { $0.category == .volume })
        #expect(insights.contains(.activeDaysChange(currentDays: 4, previousDays: 2)))
    }

    @Test
    func volumeChangeFiresAtExactlyTheDeltaFloor() {
        let metric = makeMetric()
        addDuration(500, to: metric, at: day(8))
        addDuration(500, to: metric, at: day(9))
        addDuration(600, to: metric, at: hour(9, daysAgo: 1))
        addDuration(600, to: metric, at: hour(18, daysAgo: 3))

        let insights = generate(for: metric)

        #expect(insights.contains(.volumeChange(
            measurementType: .duration, unit: nil,
            currentTotal: 1200, previousTotal: 1000,
            currentCount: 2, previousCount: 2
        )))
    }

    @Test
    func volumeChangeStaysSilentBelowTheDeltaFloor() {
        // 1100 vs 1000 is a 10% swing — under the 20% floor.
        let metric = makeMetric()
        addDuration(500, to: metric, at: day(8))
        addDuration(500, to: metric, at: day(9))
        addDuration(550, to: metric, at: hour(9, daysAgo: 1))
        addDuration(550, to: metric, at: hour(18, daysAgo: 3))

        let insights = generate(for: metric)

        #expect(!insights.contains { $0.category == .volume })
    }

    @Test
    func volumeChangeNeedsABaseline() {
        // Two zero-length previous sessions leave nothing to compare against.
        let metric = makeMetric()
        addDuration(0, to: metric, at: day(8))
        addDuration(0, to: metric, at: day(9))
        addDuration(600, to: metric, at: hour(9, daysAgo: 1))
        addDuration(600, to: metric, at: hour(18, daysAgo: 3))

        let insights = generate(for: metric)

        #expect(!insights.contains { $0.category == .volume })
    }

    // MARK: - Active days & goal hits

    @Test
    func activeDaysChangeNeedsATwoDaySwing() {
        let metric = makeMetric()
        addDuration(600, to: metric, at: day(8))
        addDuration(600, to: metric, at: day(9))
        addDuration(600, to: metric, at: hour(9, daysAgo: 1))
        addDuration(600, to: metric, at: hour(18, daysAgo: 2))
        addDuration(600, to: metric, at: hour(14, daysAgo: 3))

        let insights = generate(for: metric)

        // 3 vs 2 active days — one short of the floor.
        #expect(!insights.contains { $0.category == .consistency })
    }

    @Test
    func goalHitRateChangeFiresAtTheSwingFloor() {
        let metric = makeMetric(dailyGoal: 600)
        addDuration(600, to: metric, at: day(8))
        addDuration(600, to: metric, at: hour(9, daysAgo: 1))
        addDuration(600, to: metric, at: hour(18, daysAgo: 2))
        addDuration(600, to: metric, at: hour(14, daysAgo: 3))

        let insights = generate(for: metric)

        #expect(insights.contains(.goalHitRateChange(currentHits: 3, previousHits: 1)))
    }

    @Test
    func goalHitRateChangeNeedsATwoHitSwing() {
        let metric = makeMetric(dailyGoal: 600)
        addDuration(600, to: metric, at: day(8))
        addDuration(600, to: metric, at: hour(9, daysAgo: 1))
        addDuration(600, to: metric, at: hour(18, daysAgo: 2))

        let insights = generate(for: metric)

        #expect(!insights.contains { $0.category == .goal })
    }
}
