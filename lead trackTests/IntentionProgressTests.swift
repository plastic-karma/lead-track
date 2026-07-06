import Foundation
import Testing
@testable import lead_track
#if canImport(SwiftData)
import SwiftData
#endif

/// The live progress recompute across the whole matrix: kind × mode × perDay
/// × mid-week creation, tick de-dup per day, project-session qualification
/// and de-dup, binary-metric derivation, and running-session exclusion.
struct IntentionProgressTests {
    private let calendar = Calendar.current

    #if canImport(SwiftData)
    private let context: ModelContext

    init() throws {
        let container = try SharedModelContainer.create(inMemoryOnly: true)
        context = ModelContext(container)
    }
    #endif

    // MARK: - Fixtures

    /// Start of the current calendar week — every fixture lives inside it so
    /// the intention and its sessions always agree on the week.
    private var weekStart: Date {
        Intention.weekStart(containing: .now, calendar: calendar)
    }

    private func inWeek(day: Int, hour: Int = 9) -> Date {
        calendar.date(byAdding: DateComponents(day: day, hour: hour), to: weekStart)!
    }

    private func makeAspiration() -> Aspiration {
        let aspiration = Aspiration(title: "Vitality")
        #if canImport(SwiftData)
        context.insert(aspiration)
        #endif
        return aspiration
    }

    private func makeMetric(type: MeasurementType = .duration, unit: String? = nil) -> Metric {
        let metric = Metric(name: "Walking", measurementType: type, unit: unit)
        #if canImport(SwiftData)
        context.insert(metric)
        #endif
        return metric
    }

    private func makeProject(of metric: Metric) -> Project {
        let project = Project(name: "Trails", metric: metric)
        #if canImport(SwiftData)
        context.insert(project)
        #else
        metric.projects.append(project)
        #endif
        return project
    }

    private func addSession(
        to metric: Metric?,
        project: Project? = nil,
        at start: Date,
        duration: TimeInterval? = 600,
        value: Double? = nil
    ) {
        let session = Session(
            metric: metric, project: project, startedAt: start,
            endedAt: duration.map { start.addingTimeInterval($0) }, value: value
        )
        #if canImport(SwiftData)
        context.insert(session)
        #else
        metric?.sessions.append(session)
        project?.sessions.append(session)
        #endif
    }

    private func counted(perDay: Bool = false, target: Double? = nil, createdAt: Date? = nil) throws -> Intention {
        try Intention.make(
            title: "3 long walks", kind: .counted, aspiration: makeAspiration(),
            perDay: perDay, target: target, createdAt: createdAt ?? weekStart, calendar: calendar
        )
    }

    private func derived(
        _ metric: Metric,
        mode: DerivedMode = .sessionCount,
        perDay: Bool = false,
        target: Double? = nil
    ) throws -> Intention {
        try Intention.make(
            title: "3 walks", kind: .derived, aspiration: makeAspiration(),
            derivedMode: mode, metric: metric, perDay: perDay, target: target,
            createdAt: weekStart, calendar: calendar
        )
    }
}

// MARK: - Reflective & degraded

extension IntentionProgressTests {
    @Test
    func reflectiveHasNoProgressValue() throws {
        let intention = try Intention.make(title: "be present", kind: .reflective, aspiration: makeAspiration())
        #expect(IntentionProgress.compute(for: intention, calendar: calendar) == nil)
    }

    @Test
    func derivedWithoutItsMetricHasNoProgress() throws {
        let intention = try derived(makeMetric(), target: 3)
        intention.metric = nil
        #expect(intention.isSourceRemoved)
        #expect(IntentionProgress.compute(for: intention, calendar: calendar) == nil)
    }
}

// MARK: - Counted

extension IntentionProgressTests {
    @Test
    func countedWeeklyCountsEveryTick() throws {
        let intention = try counted(target: 3)
        for day in 0 ..< 5 {
            intention.tick(at: inWeek(day: day), calendar: calendar)
        }
        let progress = IntentionProgress.compute(for: intention, calendar: calendar)
        #expect(progress?.value == 5)
        #expect(progress?.target == 3)
        #expect(progress?.text == "5 of 3")
    }

    @Test
    func countedPerDayCountsDistinctDaysNotTicks() throws {
        let intention = try counted(perDay: true)
        intention.tick(at: inWeek(day: 0, hour: 8), calendar: calendar)
        intention.tick(at: inWeek(day: 0, hour: 20), calendar: calendar)
        intention.tick(at: inWeek(day: 2), calendar: calendar)
        let progress = IntentionProgress.compute(for: intention, calendar: calendar)
        #expect(progress?.value == 2)
        #expect(progress?.target == 7)
        #expect(progress?.text == "2 of 7 days")
    }

    @Test
    func midWeekCreationShrinksTheEligibleDays() throws {
        let intention = try counted(perDay: true, createdAt: inWeek(day: 3))
        let progress = IntentionProgress.compute(for: intention, calendar: calendar)
        #expect(progress?.target == 4)
        #expect(progress?.text == "0 of 4 days")
    }

    @Test
    func ticksBeforeTheCommitmentDoNotAdvancePerDayProgress() throws {
        let intention = try counted(perDay: true, createdAt: inWeek(day: 3))
        intention.tick(at: inWeek(day: 0), calendar: calendar)
        intention.tick(at: inWeek(day: 4), calendar: calendar)
        let progress = IntentionProgress.compute(for: intention, calendar: calendar)
        #expect(intention.tickDates.count == 2)
        #expect(progress?.value == 1)
        #expect(progress?.text == "1 of 4 days")
    }
}

// MARK: - Derived · sessionCount

extension IntentionProgressTests {
    @Test
    func derivedSessionCountCountsCompletedSessionsInTheWeek() throws {
        let metric = makeMetric()
        let beforeThisWeek = try #require(calendar.date(byAdding: .day, value: -1, to: weekStart))
        addSession(to: metric, at: inWeek(day: 0))
        addSession(to: metric, at: inWeek(day: 2))
        addSession(to: metric, at: beforeThisWeek)
        addSession(to: metric, at: inWeek(day: 1), duration: nil)
        let intention = try derived(metric, target: 3)
        let progress = IntentionProgress.compute(for: intention, calendar: calendar)
        #expect(progress?.value == 2)
        #expect(progress?.text == "2 of 3")
    }

    @Test
    func projectSessionsQualifyAndCountOnce() throws {
        let metric = makeMetric()
        let project = makeProject(of: metric)
        addSession(to: metric, project: project, at: inWeek(day: 0))
        addSession(to: nil, project: project, at: inWeek(day: 1))
        let intention = try derived(metric, target: 3)
        let progress = IntentionProgress.compute(for: intention, calendar: calendar)
        #expect(progress?.value == 2)
    }

    @Test
    func derivedPerDayCountsDistinctSessionDays() throws {
        let metric = makeMetric()
        addSession(to: metric, at: inWeek(day: 0, hour: 8))
        addSession(to: metric, at: inWeek(day: 0, hour: 18))
        addSession(to: metric, at: inWeek(day: 3))
        let intention = try derived(metric, perDay: true)
        let progress = IntentionProgress.compute(for: intention, calendar: calendar)
        #expect(progress?.value == 2)
        #expect(progress?.target == 7)
        #expect(progress?.text == "2 of 7 days")
    }

    @Test
    func binaryMetricsDeriveFromTheirDoneDays() throws {
        let metric = makeMetric(type: .binary)
        addSession(to: metric, at: inWeek(day: 0), duration: nil, value: 1)
        addSession(to: metric, at: inWeek(day: 1), duration: nil, value: 1)
        let intention = try derived(metric, target: 5)
        let progress = IntentionProgress.compute(for: intention, calendar: calendar)
        #expect(progress?.value == 2)
        #expect(progress?.text == "2 of 5")
    }
}

// MARK: - Derived · valueSum

extension IntentionProgressTests {
    @Test
    func valueSumTotalsDurationInTheMetricsUnit() throws {
        let metric = makeMetric()
        addSession(to: metric, at: inWeek(day: 0), duration: 3600)
        addSession(to: metric, at: inWeek(day: 1), duration: 2400)
        let intention = try derived(metric, mode: .valueSum, target: 4 * 3600)
        let progress = IntentionProgress.compute(for: intention, calendar: calendar)
        #expect(progress?.value == 6000)
        #expect(progress?.text == "1h 40m of 4h 00m")
    }

    @Test
    func valueSumTotalsCountsInTheMetricsUnit() throws {
        let metric = makeMetric(type: .count, unit: "pages")
        addSession(to: metric, at: inWeek(day: 0), duration: nil, value: 30)
        addSession(to: metric, at: inWeek(day: 1), duration: nil, value: 10)
        let intention = try derived(metric, mode: .valueSum, target: 50)
        let progress = IntentionProgress.compute(for: intention, calendar: calendar)
        #expect(progress?.value == 40)
        #expect(progress?.text == "40 of 50 pages")
    }
}

// MARK: - Fraction

extension IntentionProgressTests {
    @Test
    func fractionIsTheAccumulatedShareOfTheTarget() {
        let progress = IntentionProgress(value: 2, target: 3, text: "2 of 3")
        #expect(progress.fraction == 2.0 / 3.0)
    }

    @Test
    func fractionCapsAtAFullBarWhenTheTargetIsExceeded() {
        let progress = IntentionProgress(value: 5, target: 3, text: "5 of 3")
        #expect(progress.fraction == 1)
    }

    @Test
    func fractionIsNilWithoutATargetToFillToward() {
        let progress = IntentionProgress(value: 2, target: 0, text: "2 of 0")
        #expect(progress.fraction == nil)
    }
}
