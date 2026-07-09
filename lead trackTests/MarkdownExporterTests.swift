import Foundation
import Testing
@testable import lead_track
#if canImport(SwiftData)
import SwiftData
#endif

/// The markdown artifact's fixed skeleton: title, reading instructions,
/// aspiration and metric profiles, and the range totals — everything ahead
/// of the week-by-week chronology (covered in
/// `MarkdownExportWeeksTests`).
struct MarkdownExporterTests {
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

    private func makeAspiration(_ title: String = "Grow wiser") -> Aspiration {
        let aspiration = Aspiration(title: title)
        #if canImport(SwiftData)
        context.insert(aspiration)
        #endif
        return aspiration
    }

    @discardableResult
    private func makeProject(_ name: String, under metric: Metric) -> Project {
        let project = Project(name: name, metric: metric)
        #if canImport(SwiftData)
        context.insert(project)
        #else
        metric.projects.append(project)
        #endif
        return project
    }

    private func addDuration(_ seconds: TimeInterval, to metric: Metric, at start: Date) {
        let session = Session(
            metric: metric, startedAt: start, endedAt: start.addingTimeInterval(seconds)
        )
        #if canImport(SwiftData)
        context.insert(session)
        #else
        metric.sessions.append(session)
        #endif
    }

    private func build(
        metrics: [Metric] = [],
        aspirations: [Aspiration] = [],
        range: ExportRange = .allTime
    ) -> String {
        MarkdownExporter.buildMarkdown(
            data: MarkdownExportData(metrics: metrics, aspirations: aspirations),
            range: range,
            calendar: calendar
        )
    }

    // MARK: - Skeleton

    @Test
    func documentOpensWithTitleAndReadingInstructions() {
        let markdown = build()
        #expect(markdown.hasPrefix("# lead track — data export"))
        #expect(markdown.contains("## How to read this file"))
    }

    @Test
    func headerNamesTheRange() {
        #expect(build(range: .lastMonths(3)).contains("- Range: Last 3 Months ("))
        #expect(build(range: .allTime).contains("- Range: All Time (everything through"))
    }

    @Test
    func emptyRangeSaysSoInsteadOfWeekSections() {
        let markdown = build(metrics: [makeMetric()])
        #expect(markdown.contains("No recorded data in this range."))
        #expect(!markdown.contains("## Week of"))
    }

    @Test
    func filenameCarriesTheRangeSlug() {
        #expect(MarkdownExporter.filename(range: .lastMonths(3)) == "lead-track-last-3-months.md")
        #expect(MarkdownExporter.filename(range: .allTime) == "lead-track-all-time.md")
    }

    // MARK: - Aspiration Profiles

    @Test
    func aspirationProfileCarriesDetailAndAttachments() {
        let aspiration = makeAspiration()
        aspiration.detail = "Read widely, think slowly."
        let metric = makeMetric(name: "Reading")
        let project = makeProject("War and Peace", under: metric)
        aspiration.metrics.append(metric)
        aspiration.projects.append(project)

        let markdown = build(metrics: [metric], aspirations: [aspiration])

        #expect(markdown.contains("## Aspirations"))
        #expect(markdown.contains("### Grow wiser"))
        #expect(markdown.contains("Read widely, think slowly."))
        #expect(markdown.contains("- Attached metrics: Reading"))
        #expect(markdown.contains("- Attached projects: War and Peace (under Reading)"))
    }

    @Test
    func unattachedAspirationSaysSo() {
        let markdown = build(aspirations: [makeAspiration()])
        #expect(markdown.contains("- No metrics or projects attached yet."))
    }

    // MARK: - Metric Profiles

    @Test
    func metricProfileSpellsTypeGoalsAndProjects() {
        let metric = makeMetric()
        metric.dailyGoal = 3600
        metric.weeklyGoal = 18000
        makeProject("Novel draft", under: metric)

        let markdown = build(metrics: [metric])

        #expect(markdown.contains("### Writing (duration)"))
        #expect(markdown.contains("- Daily goal: 1h 00m"))
        #expect(markdown.contains("- Weekly goal: 5h 00m"))
        #expect(markdown.contains("- Projects: Novel draft (active)"))
    }

    @Test
    func countMetricHeadingCarriesItsUnit() {
        let markdown = build(metrics: [makeMetric(name: "Reading", type: .count, unit: "pages")])
        #expect(markdown.contains("### Reading (count, unit: pages)"))
    }

    @Test
    func healthLinkedMetricNamesItsSource() {
        let metric = Metric(
            name: "Move", measurementType: .count, unit: "kcal", healthSource: .activeCalories
        )
        #if canImport(SwiftData)
        context.insert(metric)
        #endif
        let markdown = build(metrics: [metric])
        #expect(markdown.contains("- Mirrored from Apple Health: Active Calories"))
    }

    // MARK: - Range Totals

    @Test
    func totalsSumEachMetricAcrossTheRange() {
        let metric = makeMetric()
        addDuration(3600, to: metric, at: day(1))
        addDuration(1800, to: metric, at: day(3))

        let markdown = build(metrics: [metric])

        #expect(markdown.contains("## Totals for this range"))
        #expect(markdown.contains("- Writing: 1h 30m across 2 sessions"))
    }

    @Test
    func untouchedMetricStillGetsATotalsLine() {
        let quiet = makeMetric(name: "Idle")
        let busy = makeMetric(name: "Writing")
        addDuration(600, to: busy, at: day(1))

        let markdown = build(metrics: [quiet, busy])

        #expect(markdown.contains("- Idle: no sessions in this range"))
    }

    @Test
    func inventoryCountsWhatTheRangeHolds() {
        let metric = makeMetric()
        addDuration(600, to: metric, at: day(1))
        let markdown = build(metrics: [metric])
        #expect(markdown.contains("Moments: 0 · Intentions: 0 · Check-ins: 0"))
    }
}
