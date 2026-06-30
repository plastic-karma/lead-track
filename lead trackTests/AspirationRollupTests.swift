import Foundation
import Testing
@testable import lead_track
#if canImport(SwiftData)
import SwiftData
#endif

struct AspirationRollupTests {
    private let calendar = Calendar.current

    #if canImport(SwiftData)
    /// Relationship arrays only sync through a context on Apple platforms; the
    /// Linux overlay compiles the models as plain classes and wires the arrays
    /// directly. The rollup only ever reads the side these fixtures set.
    private let context: ModelContext

    init() throws {
        let container = try SharedModelContainer.create(inMemoryOnly: true)
        context = ModelContext(container)
    }
    #endif

    // MARK: - Fixtures

    /// Midnight `daysAgo` days back — sessions placed at a day's first instant
    /// never land after "now", keeping the window math deterministic.
    private func day(_ daysAgo: Int) -> Date {
        calendar.date(
            byAdding: .day, value: -daysAgo,
            to: calendar.startOfDay(for: .now)
        )!
    }

    private func makeAspiration() -> Aspiration {
        let aspiration = Aspiration(title: "Grow wiser")
        #if canImport(SwiftData)
        context.insert(aspiration)
        #endif
        return aspiration
    }

    private func makeMetric(
        name: String = "Reading",
        type: MeasurementType = .duration,
        unit: String? = nil
    ) -> Metric {
        let metric = Metric(name: name, measurementType: type, unit: unit)
        #if canImport(SwiftData)
        context.insert(metric)
        #endif
        return metric
    }

    private func makeProject(_ name: String, of metric: Metric) -> Project {
        let project = Project(name: name, metric: metric)
        #if canImport(SwiftData)
        context.insert(project)
        #else
        metric.projects.append(project)
        #endif
        return project
    }

    private func addDuration(
        _ seconds: TimeInterval,
        to metric: Metric,
        project: Project? = nil,
        at start: Date
    ) {
        register(
            Session(
                metric: metric, project: project,
                startedAt: start, endedAt: start.addingTimeInterval(seconds)
            ),
            metric: metric, project: project
        )
    }

    private func addCount(
        _ value: Double,
        to metric: Metric,
        project: Project? = nil,
        at start: Date
    ) {
        register(
            Session(metric: metric, project: project, startedAt: start, value: value),
            metric: metric, project: project
        )
    }

    private func register(_ session: Session, metric: Metric, project: Project?) {
        #if canImport(SwiftData)
        context.insert(session)
        #else
        metric.sessions.append(session)
        project?.sessions.append(session)
        #endif
    }
}

// MARK: - Mixed units

extension AspirationRollupTests {
    @Test
    func headlineCollapsesDurationAndSplitsCountUnits() {
        let aspiration = makeAspiration()
        let reading = makeMetric(name: "Reading", type: .duration)
        addDuration(7200, to: reading, at: day(0))
        let pages = makeMetric(name: "Pages", type: .count, unit: "pages")
        addCount(340, to: pages, at: day(0))
        aspiration.metrics.append(reading)
        aspiration.metrics.append(pages)

        let rollup = AspirationRollup.compute(for: aspiration)

        #expect(rollup.lifetimeSummary == "2h 00m · 340 pages")
        #expect(rollup.headline.count == 2)
        #expect(rollup.headline.first?.kind == .duration)
    }

    @Test
    func unitGroupingNormalizesSpellings() {
        let aspiration = makeAspiration()
        let first = makeMetric(name: "Novels", type: .count, unit: "pages")
        addCount(100, to: first, at: day(0))
        let second = makeMetric(name: "Papers", type: .count, unit: "Pages ")
        addCount(40, to: second, at: day(0))
        aspiration.metrics.append(first)
        aspiration.metrics.append(second)

        let rollup = AspirationRollup.compute(for: aspiration)

        #expect(rollup.headline.count == 1)
        #expect(rollup.lifetimeSummary == "140 pages")
    }

    @Test
    func noUnitCountFallsBackToEntryCount() {
        let aspiration = makeAspiration()
        let metric = makeMetric(name: "Wins", type: .count, unit: nil)
        addCount(5, to: metric, at: day(0))
        addCount(8, to: metric, at: day(1))
        aspiration.metrics.append(metric)

        let rollup = AspirationRollup.compute(for: aspiration)

        // The headline counts occurrences, not the summed value (5 + 8).
        #expect(rollup.lifetimeSummary == "2 entries")
        #expect(rollup.headline.first?.kind == .entries)
    }
}

// MARK: - De-dup

extension AspirationRollupTests {
    @Test
    func attachedMetricIncludesItsProjectsSessions() {
        let aspiration = makeAspiration()
        let metric = makeMetric(type: .duration)
        let project = makeProject("Sapiens", of: metric)
        addDuration(600, to: metric, at: day(0))
        addDuration(600, to: metric, at: day(1))
        addDuration(600, to: metric, project: project, at: day(2))
        aspiration.metrics.append(metric)

        let rollup = AspirationRollup.compute(for: aspiration)

        #expect(rollup.headline.first?.lifetime == 1800)
    }

    @Test
    func projectIsNotDoubleCountedWhenItsMetricIsAlsoAttached() {
        let aspiration = makeAspiration()
        let metric = makeMetric(type: .duration)
        let project = makeProject("Sapiens", of: metric)
        addDuration(600, to: metric, at: day(0))
        addDuration(600, to: metric, project: project, at: day(1))
        aspiration.metrics.append(metric)
        aspiration.projects.append(project)

        let rollup = AspirationRollup.compute(for: aspiration)

        #expect(rollup.attachmentCount == 1)
        #expect(rollup.headline.first?.lifetime == 1200)
    }

    @Test
    func standaloneProjectCountsWhenItsMetricIsNotAttached() {
        let aspiration = makeAspiration()
        let metric = makeMetric(type: .duration)
        let project = makeProject("Sapiens", of: metric)
        addDuration(600, to: metric, at: day(0))
        addDuration(900, to: metric, project: project, at: day(1))
        aspiration.projects.append(project)

        let rollup = AspirationRollup.compute(for: aspiration)

        #expect(rollup.attachmentCount == 1)
        #expect(rollup.headline.first?.lifetime == 900)
    }
}

// MARK: - Lifetime + recent

extension AspirationRollupTests {
    @Test
    func recentWindowExcludesOlderSessions() {
        let aspiration = makeAspiration()
        let metric = makeMetric(type: .count, unit: "pages")
        addCount(10, to: metric, at: day(0))
        addCount(5, to: metric, at: day(40))
        aspiration.metrics.append(metric)

        let rollup = AspirationRollup.compute(for: aspiration)

        #expect(rollup.headline.first?.lifetime == 15)
        #expect(rollup.headline.first?.recent == 10)
        #expect(rollup.recentParts == ["10 pages"])
    }

    @Test
    func reattachingRestoresFullHistory() {
        let aspiration = makeAspiration()
        let metric = makeMetric(type: .duration)
        addDuration(1200, to: metric, at: day(3))
        aspiration.metrics.append(metric)
        #expect(AspirationRollup.compute(for: aspiration).headline.first?.lifetime == 1200)

        aspiration.metrics.removeAll()
        #expect(AspirationRollup.compute(for: aspiration).hasData == false)

        aspiration.metrics.append(metric)
        #expect(AspirationRollup.compute(for: aspiration).headline.first?.lifetime == 1200)
    }
}

// MARK: - Empty / zero states

extension AspirationRollupTests {
    @Test
    func emptyAspirationHasNoAttachmentsOrData() {
        let rollup = AspirationRollup.compute(for: makeAspiration())

        #expect(rollup.attachmentCount == 0)
        #expect(rollup.hasData == false)
        #expect(rollup.lifetimeSummary.isEmpty)
    }

    @Test
    func attachmentWithoutSessionsIsZeroedNotEmpty() {
        let aspiration = makeAspiration()
        aspiration.metrics.append(makeMetric(type: .duration))

        let rollup = AspirationRollup.compute(for: aspiration)

        #expect(rollup.attachmentCount == 1)
        #expect(rollup.hasData == false)
    }
}

// MARK: - Poured into today

extension AspirationRollupTests {
    @Test
    func receivedEffortTodayWhenAnAttachmentLoggedToday() {
        let aspiration = makeAspiration()
        let metric = makeMetric(type: .duration)
        addDuration(600, to: metric, at: day(0))
        aspiration.metrics.append(metric)

        #expect(AspirationRollup.receivedEffortToday(aspiration))
    }

    @Test
    func noEffortTodayWhenOnlyOlderSessions() {
        let aspiration = makeAspiration()
        let metric = makeMetric(type: .duration)
        addDuration(600, to: metric, at: day(1))
        aspiration.metrics.append(metric)

        #expect(!AspirationRollup.receivedEffortToday(aspiration))
    }

    @Test
    func receivedEffortTodayThroughAStandaloneProject() {
        let aspiration = makeAspiration()
        let metric = makeMetric(type: .duration)
        let project = makeProject("Sapiens", of: metric)
        addDuration(900, to: metric, project: project, at: day(0))
        aspiration.projects.append(project)

        #expect(AspirationRollup.receivedEffortToday(aspiration))
    }

    @Test
    func noEffortTodayWhenNothingAttached() {
        #expect(!AspirationRollup.receivedEffortToday(makeAspiration()))
    }
}
