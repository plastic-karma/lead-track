import Foundation
import Testing
@testable import lead_track
#if canImport(SwiftData)
import SwiftData
#endif

/// The markdown artifact's chronology: week sections oldest first, day
/// subsections inside them, and the aggregation rules their metric lines
/// follow. Intention, check-in, and moment lines are covered in
/// `MarkdownExportLineTests`.
struct MarkdownExportWeeksTests {
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

    private func day(_ daysAgo: Int) -> Date {
        calendar.date(
            byAdding: .day, value: -daysAgo,
            to: calendar.startOfDay(for: .now)
        )!
    }

    private func makeMetric(
        name: String = "Writing",
        type: MeasurementType = .duration,
        unit: String? = nil
    ) -> Metric {
        let metric = Metric(name: name, measurementType: type, unit: unit)
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

    private func addDuration(_ seconds: TimeInterval, to metric: Metric, at start: Date) {
        register(
            Session(metric: metric, startedAt: start, endedAt: start.addingTimeInterval(seconds)),
            with: metric
        )
    }

    private func addCount(_ value: Double, to metric: Metric, at start: Date) {
        register(Session(metric: metric, startedAt: start, value: value), with: metric)
    }

    private func build(_ data: MarkdownExportData, range: ExportRange = .allTime) -> String {
        MarkdownExporter.buildMarkdown(data: data, range: range, calendar: calendar)
    }

    private func heading(_ daysAgo: Int) -> String {
        "### \(MarkdownExportDates.dayHeading(day(daysAgo)))"
    }
}

// MARK: - Weeks and Days

extension MarkdownExportWeeksTests {
    @Test
    func weeksReadOldestFirstWithTheirDaysInside() throws {
        let metric = makeMetric()
        addDuration(600, to: metric, at: day(21))
        addDuration(600, to: metric, at: day(0))

        let markdown = build(MarkdownExportData(metrics: [metric]))

        let older = try #require(markdown.range(of: heading(21)))
        let newer = try #require(markdown.range(of: heading(0)))
        #expect(older.lowerBound < newer.lowerBound)
        #expect(markdown.contains("## Week of"))
    }

    @Test
    func emptyDaysBetweenLoggedDaysAreOmitted() {
        let metric = makeMetric()
        addDuration(600, to: metric, at: day(2))
        addDuration(600, to: metric, at: day(0))

        let markdown = build(MarkdownExportData(metrics: [metric]))

        #expect(markdown.contains(heading(2)))
        #expect(!markdown.contains(heading(1)))
    }

    @Test
    func dayLinesAggregateTheDaysSessions() {
        let metric = makeMetric()
        addDuration(2400, to: metric, at: day(1))
        addDuration(1200, to: metric, at: day(1).addingTimeInterval(3600))

        let markdown = build(MarkdownExportData(metrics: [metric]))

        #expect(markdown.contains("- Writing: 1h 00m (2 sessions)"))
    }

    /// The week line says "(1 session)"; the day line drops the count — a
    /// bare "- Push-ups: 40 reps" followed directly by the line break.
    @Test
    func singleSessionDayCarriesNoSessionCount() {
        let metric = makeMetric(name: "Push-ups", type: .count, unit: "reps")
        addCount(40, to: metric, at: day(1))

        let markdown = build(MarkdownExportData(metrics: [metric]))

        #expect(markdown.contains("- Push-ups: 40 reps\n"))
        #expect(markdown.contains("- Push-ups: 40 reps (1 session)"))
    }

    @Test
    func binaryMetricDayReadsDone() {
        let metric = makeMetric(name: "Meditate", type: .binary)
        addCount(1, to: metric, at: day(1))
        addCount(1, to: metric, at: day(2))

        let markdown = build(MarkdownExportData(metrics: [metric]))

        #expect(markdown.contains("- Meditate: done"))
        #expect(markdown.contains("- Meditate: 2 days"))
    }

    @Test
    func weeklyTotalsStateTheGoalWithoutJudging() {
        let metric = makeMetric()
        metric.weeklyGoal = 18000
        addDuration(3600, to: metric, at: day(0))

        let markdown = build(MarkdownExportData(metrics: [metric]))

        #expect(markdown.contains("**Week totals**"))
        #expect(markdown.contains("- Writing: 1h 00m (1 session) — weekly goal 5h 00m"))
    }

    @Test
    func projectSessionsCountOnce() {
        let metric = makeMetric()
        let project = Project(name: "Novel draft", metric: metric)
        let session = Session(
            metric: metric, project: project, startedAt: day(1),
            endedAt: day(1).addingTimeInterval(600)
        )
        #if canImport(SwiftData)
        context.insert(project)
        context.insert(session)
        #else
        metric.projects.append(project)
        metric.sessions.append(session)
        project.sessions.append(session)
        #endif

        let markdown = build(MarkdownExportData(metrics: [metric]))

        #expect(markdown.contains("- Writing: 10m 00s across 1 session"))
    }

    @Test
    func runningSessionsNeverCount() {
        let metric = makeMetric()
        register(Session(metric: metric, startedAt: day(0)), with: metric)

        let markdown = build(MarkdownExportData(metrics: [metric]))

        #expect(markdown.contains("No recorded data in this range."))
    }

    @Test
    func sessionsBeforeTheCutoffStayOut() {
        let metric = makeMetric()
        addDuration(600, to: metric, at: day(30))

        let markdown = build(MarkdownExportData(metrics: [metric]), range: .last7Days)

        #expect(markdown.contains("- Writing: no sessions in this range"))
        #expect(!markdown.contains("## Week of"))
    }
}
