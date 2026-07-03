import Foundation
import Testing
@testable import lead_track
#if canImport(SwiftData)
import SwiftData
#endif

struct MeasureHealthTests {
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

    /// Midnight `daysAgo` days back.
    private func day(_ daysAgo: Int) -> Date {
        calendar.date(
            byAdding: .day, value: -daysAgo,
            to: calendar.startOfDay(for: .now)
        )!
    }

    private var now: Date {
        day(0)
    }

    private func makeMetric(
        name: String = "Reading",
        type: MeasurementType = .duration,
        dailyGoal: TimeInterval? = nil
    ) -> Metric {
        let metric = Metric(name: name, measurementType: type)
        metric.dailyGoal = dailyGoal
        #if canImport(SwiftData)
        context.insert(metric)
        #endif
        return metric
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

    private func register(_ session: Session, with metric: Metric) {
        #if canImport(SwiftData)
        context.insert(session)
        #else
        metric.sessions.append(session)
        #endif
    }

    /// A month-old anchor session so the history guard passes without
    /// entering the 28-day window.
    private func anchorHistory(of metric: Metric, seconds: TimeInterval = 1800) {
        addDuration(seconds, to: metric, at: day(35))
    }

    /// `daysAgo` days back at the given wall-clock hour.
    private func hour(_ hour: Int, daysAgo: Int) -> Date {
        calendar.date(byAdding: .hour, value: hour, to: day(daysAgo))!
    }

    // MARK: - Goal clustering

    /// `banded` days just over the goal, `wide` days far past it, one hit per
    /// day inside the window.
    private func clusteredMetric(banded: Int, wide: Int) -> Metric {
        let metric = makeMetric(dailyGoal: 600)
        anchorHistory(of: metric, seconds: 300)
        for index in 0 ..< banded {
            addDuration(630, to: metric, at: day(1 + index))
        }
        for index in 0 ..< wide {
            addDuration(1800, to: metric, at: day(1 + banded + index))
        }
        return metric
    }

    @Test
    func goalClusteringFiresWhenHitsHugTheLine() {
        let metric = clusteredMetric(banded: 8, wide: 2)

        let insight = MeasureHealth.detectGoalClustering(metric: metric, now: now)

        #expect(insight == .goalClustering(bandedHits: 8, totalHits: 10))
        #expect(insight?.category == .measureHealth)
    }

    @Test
    func goalClusteringStaysSilentWithoutGoal() {
        let metric = clusteredMetric(banded: 8, wide: 2)
        metric.dailyGoal = nil

        #expect(MeasureHealth.detectGoalClustering(metric: metric, now: now) == nil)
    }

    @Test
    func goalClusteringStaysSilentOnYoungHistory() {
        let metric = makeMetric(dailyGoal: 600)
        for index in 0 ..< 10 {
            addDuration(630, to: metric, at: day(1 + index))
        }

        #expect(MeasureHealth.detectGoalClustering(metric: metric, now: now) == nil)
    }

    @Test
    func goalClusteringStaysSilentBelowMinHitDays() {
        let metric = clusteredMetric(banded: 7, wide: 0)

        #expect(MeasureHealth.detectGoalClustering(metric: metric, now: now) == nil)
    }

    @Test
    func goalClusteringStaysSilentWhenHitsSpread() {
        let metric = clusteredMetric(banded: 6, wide: 4)

        #expect(MeasureHealth.detectGoalClustering(metric: metric, now: now) == nil)
    }

    // MARK: - Streak saver

    /// A live streak of typical sessions with `saves` tiny late sole-session
    /// days folded in.
    private func streakMetric(saves: Int) -> Metric {
        let metric = makeMetric()
        anchorHistory(of: metric)
        for daysAgo in 0 ... 9 {
            if daysAgo >= 2, daysAgo < 2 + saves {
                addDuration(300, to: metric, at: hour(21, daysAgo: daysAgo))
            } else {
                addDuration(1800, to: metric, at: day(daysAgo))
            }
        }
        return metric
    }

    @Test
    func streakSaverFiresOnTinyLateSoleSessions() {
        let metric = streakMetric(saves: 2)

        let insight = MeasureHealth.detectStreakSaver(metric: metric, now: now)

        #expect(insight == .streakSaver(occurrences: 2, streak: 10))
    }

    @Test
    func streakSaverStaysSilentBelowTwoSaves() {
        let metric = streakMetric(saves: 1)

        #expect(MeasureHealth.detectStreakSaver(metric: metric, now: now) == nil)
    }

    @Test
    func streakSaverStaysSilentWithoutLongStreak() {
        let metric = makeMetric()
        anchorHistory(of: metric)
        for daysAgo in 0 ... 4 {
            addDuration(daysAgo < 2 ? 300 : 1800, to: metric, at: hour(21, daysAgo: daysAgo))
        }

        #expect(MeasureHealth.detectStreakSaver(metric: metric, now: now) == nil)
    }

    @Test
    func streakSaverStaysSilentBeforeLateHour() {
        let metric = makeMetric()
        anchorHistory(of: metric)
        for daysAgo in 0 ... 9 {
            if daysAgo == 2 || daysAgo == 3 {
                addDuration(300, to: metric, at: hour(20, daysAgo: daysAgo))
            } else {
                addDuration(1800, to: metric, at: day(daysAgo))
            }
        }

        #expect(MeasureHealth.detectStreakSaver(metric: metric, now: now) == nil)
    }

    @Test
    func streakSaverSkipsBinaryAndHealthLinkedMetrics() {
        let binary = makeMetric(type: .binary)
        let mirrored = Metric(name: "Exercise", healthSource: .exerciseMinutes)
        #if canImport(SwiftData)
        context.insert(mirrored)
        #endif

        #expect(MeasureHealth.detectStreakSaver(metric: binary, now: now) == nil)
        #expect(MeasureHealth.detectStreakSaver(metric: mirrored, now: now) == nil)
    }

    // MARK: - Narrowing

    /// Three attached metrics: A dominant recently, B and C active only in
    /// the prior window.
    private func narrowedAspiration(recentA: Int = 12) -> Aspiration {
        let aspiration = Aspiration(title: "Grow wiser")
        #if canImport(SwiftData)
        context.insert(aspiration)
        #endif
        let dominant = makeMetric(name: "Reading")
        let quietOne = makeMetric(name: "Writing")
        let quietTwo = makeMetric(name: "Sketching")
        aspiration.metrics.append(contentsOf: [dominant, quietOne, quietTwo])
        for index in 0 ..< recentA {
            addDuration(600, to: dominant, at: day(1 + (index % 28)))
        }
        addDuration(600, to: quietOne, at: day(35))
        addDuration(600, to: quietTwo, at: day(40))
        return aspiration
    }

    @Test
    func narrowingFiresWhenOneSourceDominatesAndOthersGoQuiet() throws {
        let aspiration = narrowedAspiration()

        let narrowing = try #require(MeasureHealth.detectNarrowing(for: aspiration, now: now))

        #expect(narrowing.dominantName == "Reading")
        #expect(narrowing.dominantShare == 1)
        #expect(narrowing.quietNames == ["Writing", "Sketching"])
        #expect(narrowing.line.hasSuffix("?"))
    }

    @Test
    func narrowingStaysSilentBelowSessionFloor() {
        let aspiration = narrowedAspiration(recentA: 11)

        #expect(MeasureHealth.detectNarrowing(for: aspiration, now: now) == nil)
    }

    @Test
    func narrowingStaysSilentWithFewEverActiveSources() {
        let aspiration = Aspiration(title: "Grow wiser")
        #if canImport(SwiftData)
        context.insert(aspiration)
        #endif
        let dominant = makeMetric(name: "Reading")
        let quiet = makeMetric(name: "Writing")
        aspiration.metrics.append(contentsOf: [dominant, quiet])
        for index in 0 ..< 12 {
            addDuration(600, to: dominant, at: day(1 + (index % 28)))
        }
        addDuration(600, to: quiet, at: day(35))

        #expect(MeasureHealth.detectNarrowing(for: aspiration, now: now) == nil)
    }

    @Test
    func narrowingStaysSilentWhileOtherSourcesStayActive() {
        let aspiration = narrowedAspiration()
        // One of the quiet sources logs something recent.
        let active = makeMetric(name: "Journaling")
        aspiration.metrics.append(active)
        addDuration(600, to: active, at: day(35))
        addDuration(600, to: active, at: day(2))
        for metric in aspiration.metrics where metric.name == "Writing" {
            addDuration(600, to: metric, at: day(3))
        }

        #expect(MeasureHealth.detectNarrowing(for: aspiration, now: now) == nil)
    }

    // MARK: - Generator integration

    @Test
    func measureHealthLeadsInsightsAndCapsToOne() throws {
        let metric = clusteredMetric(banded: 8, wide: 2)

        let insights = InsightGenerator.generate(
            for: metric,
            currentStart: day(6),
            previousStart: day(13),
            end: now
        )

        let first = try #require(insights.first)
        #expect(first.category == .measureHealth)
        #expect(insights.count(where: { $0.category == .measureHealth }) == 1)
    }
}
