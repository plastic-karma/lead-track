import Foundation
import SwiftData
import Testing
@testable import lead_track

@MainActor
struct WatchSnapshotBuilderTests {
    @Test
    func snapshotCarriesTodayTotalAndIdentity() throws {
        let container = try SharedModelContainer.create(inMemoryOnly: true)
        let context = ModelContext(container)
        let metric = Metric(
            name: "Pages", measurementType: .count, unit: "pages", icon: "book"
        )
        context.insert(metric)
        let today = Session(
            metric: metric, startedAt: .now, endedAt: .now, value: 2
        )
        context.insert(today)
        let earlier = try #require(
            Calendar.current.date(byAdding: .day, value: -1, to: .now)
        )
        let yesterday = Session(
            metric: metric, startedAt: earlier, endedAt: earlier, value: 5
        )
        context.insert(yesterday)

        let snapshot = WatchSnapshotBuilder.snapshot(from: [metric])

        let entry = try #require(snapshot.metrics.first)
        #expect(entry.id == metric.stableID)
        #expect(entry.measurementType == .count)
        #expect(entry.unit == "pages")
        #expect(entry.todayTotal == 2)
        #expect(entry.runningSince == nil)
    }

    @Test
    func snapshotMarksRunningTimers() throws {
        let container = try SharedModelContainer.create(inMemoryOnly: true)
        let context = ModelContext(container)
        let metric = Metric(name: "Focus")
        context.insert(metric)
        let start = Date.now.addingTimeInterval(-300)
        let running = Session(metric: metric, startedAt: start)
        context.insert(running)

        let snapshot = WatchSnapshotBuilder.snapshot(from: [metric])

        let entry = try #require(snapshot.metrics.first)
        #expect(entry.runningSince == start)
        #expect(entry.todayTotal == 0)
    }

    @Test
    func snapshotOrdersMetricsByCreation() throws {
        let container = try SharedModelContainer.create(inMemoryOnly: true)
        let context = ModelContext(container)
        let newer = Metric(name: "Newer", createdAt: .now)
        let older = Metric(
            name: "Older", createdAt: .now.addingTimeInterval(-100)
        )
        context.insert(newer)
        context.insert(older)

        let snapshot = WatchSnapshotBuilder.snapshot(from: [newer, older])

        #expect(snapshot.metrics.map(\.name) == ["Older", "Newer"])
    }

    @Test
    func snapshotCarriesHealthLink() throws {
        let container = try SharedModelContainer.create(inMemoryOnly: true)
        let context = ModelContext(container)
        let metric = Metric(
            name: "Move",
            measurementType: .count,
            unit: "kcal",
            healthSource: .activeCalories
        )
        context.insert(metric)

        let snapshot = WatchSnapshotBuilder.snapshot(from: [metric])

        #expect(snapshot.metrics.first?.isHealthLinked == true)
    }

    @Test
    func snapshotCarriesGoalFieldsAndDayStamp() throws {
        let container = try SharedModelContainer.create(inMemoryOnly: true)
        let context = ModelContext(container)
        let metric = Metric(name: "Pages", measurementType: .count, unit: "pages")
        metric.dailyGoal = 10
        metric.excludedWeekdays = [1, 7]
        context.insert(metric)

        let snapshot = WatchSnapshotBuilder.snapshot(from: [metric])

        let entry = try #require(snapshot.metrics.first)
        #expect(entry.dailyGoal == 10)
        #expect(entry.excludedWeekdays == [1, 7])
        let day = try #require(snapshot.day)
        #expect(Calendar.current.isDate(day, inSameDayAs: .now))
    }

    @Test
    func binaryMetricShipsImplicitTargetWithoutAmountGoal() throws {
        let container = try SharedModelContainer.create(inMemoryOnly: true)
        let context = ModelContext(container)
        let metric = Metric(name: "Stretch", measurementType: .binary)
        context.insert(metric)

        let snapshot = WatchSnapshotBuilder.snapshot(from: [metric])

        let entry = try #require(snapshot.metrics.first)
        #expect(entry.dailyGoal == nil)
        #expect(entry.hasDailyTarget)
    }
}
