import Foundation
import Testing
@testable import lead_track
#if canImport(SwiftData)
import SwiftData
#endif

struct TodayGroupingTests {
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

    private func date(_ daysAgo: Int) -> Date {
        calendar.date(
            byAdding: .day, value: -daysAgo,
            to: calendar.startOfDay(for: .now)
        )!
    }

    private func makeMetric(_ name: String) -> Metric {
        let metric = Metric(name: name)
        #if canImport(SwiftData)
        context.insert(metric)
        #endif
        return metric
    }

    private func makeAspiration(_ title: String, daysAgo: Int) -> Aspiration {
        let aspiration = Aspiration(title: title, createdAt: date(daysAgo))
        #if canImport(SwiftData)
        context.insert(aspiration)
        #endif
        return aspiration
    }

    // MARK: - Membership

    @Test
    func attachedMetricsGroupAndOthersStayUnaligned() {
        let aspiration = makeAspiration("Grow wiser", daysAgo: 10)
        let attached = makeMetric("Reading")
        let loose = makeMetric("Chores")
        aspiration.metrics.append(attached)

        let split = TodayGrouping.groups(metrics: [attached, loose], aspirations: [aspiration])

        #expect(split.groups.count == 1)
        #expect(split.groups.first?.metrics.map(\.name) == ["Reading"])
        #expect(split.unaligned.map(\.name) == ["Chores"])
    }

    @Test
    func projectAttachmentGroupsItsMetric() {
        let aspiration = makeAspiration("Grow wiser", daysAgo: 10)
        let metric = makeMetric("Reading")
        let project = Project(name: "War and Peace", metric: metric)
        #if canImport(SwiftData)
        context.insert(project)
        #endif
        aspiration.projects.append(project)

        let split = TodayGrouping.groups(metrics: [metric], aspirations: [aspiration])

        #expect(split.groups.first?.metrics.map(\.name) == ["Reading"])
        #expect(split.unaligned.isEmpty)
    }

    @Test
    func earliestCreatedAspirationWinsSharedMetrics() {
        let older = makeAspiration("Older", daysAgo: 20)
        let newer = makeAspiration("Newer", daysAgo: 5)
        let shared = makeMetric("Reading")
        older.metrics.append(shared)
        newer.metrics.append(shared)

        let split = TodayGrouping.groups(metrics: [shared], aspirations: [newer, older])

        #expect(split.groups.count == 1)
        #expect(split.groups.first?.aspiration.title == "Older")
    }

    // MARK: - Order & completeness

    @Test
    func groupsFollowCreationOrderAndMetricsKeepTheirs() {
        let first = makeAspiration("First", daysAgo: 20)
        let second = makeAspiration("Second", daysAgo: 10)
        let one = makeMetric("One")
        let two = makeMetric("Two")
        let three = makeMetric("Three")
        second.metrics.append(one)
        first.metrics.append(contentsOf: [two, three])

        let split = TodayGrouping.groups(
            metrics: [one, two, three], aspirations: [second, first]
        )

        #expect(split.groups.map(\.aspiration.title) == ["First", "Second"])
        #expect(split.groups.first?.metrics.map(\.name) == ["Two", "Three"])
    }

    @Test
    func everyMetricAppearsExactlyOnce() {
        let first = makeAspiration("First", daysAgo: 20)
        let second = makeAspiration("Second", daysAgo: 10)
        let metrics = ["A", "B", "C", "D"].map(makeMetric)
        first.metrics.append(metrics[0])
        second.metrics.append(contentsOf: [metrics[0], metrics[1]])

        let split = TodayGrouping.groups(metrics: metrics, aspirations: [first, second])

        let grouped = split.groups.flatMap(\.metrics).map(\.name)
        #expect(grouped.count + split.unaligned.count == metrics.count)
        #expect(Set(grouped + split.unaligned.map(\.name)).count == metrics.count)
    }

    @Test
    func emptyGroupsAreDropped() {
        let quiet = makeAspiration("Quiet", daysAgo: 10)
        let loose = makeMetric("Chores")

        let split = TodayGrouping.groups(metrics: [loose], aspirations: [quiet])

        #expect(split.groups.isEmpty)
        #expect(split.unaligned.map(\.name) == ["Chores"])
    }
}
