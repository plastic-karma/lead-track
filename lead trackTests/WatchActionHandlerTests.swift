import Foundation
import SwiftData
import Testing
@testable import lead_track

@MainActor
struct WatchActionHandlerTests {
    private func makeContext() throws -> ModelContext {
        let container = try SharedModelContainer.create(inMemoryOnly: true)
        return ModelContext(container)
    }

    private func makeMetric(
        type: MeasurementType = .duration,
        in context: ModelContext
    ) -> Metric {
        let metric = Metric(name: "Reading", measurementType: type)
        context.insert(metric)
        return metric
    }

    // MARK: - Start

    @Test
    func startCreatesBackdatedRunningSession() throws {
        let context = try makeContext()
        let metric = makeMetric(in: context)
        let id = try #require(metric.stableID)
        let timestamp = Date.now.addingTimeInterval(-90)

        try WatchActionHandler.apply(
            WatchAction(kind: .startTimer, metricID: id, timestamp: timestamp),
            in: context
        )

        let session = try #require(SessionService.activeSession(for: metric))
        #expect(session.startedAt == timestamp)
    }

    @Test
    func startWhileRunningKeepsExistingSession() throws {
        let context = try makeContext()
        let metric = makeMetric(in: context)
        let id = try #require(metric.stableID)
        let existing = SessionService.startSession(for: metric, in: context)
        let originalStart = existing.startedAt

        try WatchActionHandler.apply(
            WatchAction(
                kind: .startTimer,
                metricID: id,
                timestamp: .now.addingTimeInterval(-50)
            ),
            in: context
        )

        #expect(metric.sessions.count == 1)
        #expect(existing.startedAt == originalStart)
    }

    // MARK: - Stop

    @Test
    func stopEndsSessionAtActionTimestamp() throws {
        let context = try makeContext()
        let metric = makeMetric(in: context)
        let id = try #require(metric.stableID)
        let session = Session(
            metric: metric, startedAt: .now.addingTimeInterval(-600)
        )
        context.insert(session)
        let stopTime = Date.now.addingTimeInterval(-60)

        try WatchActionHandler.apply(
            WatchAction(kind: .stopTimer, metricID: id, timestamp: stopTime),
            in: context
        )

        #expect(session.endedAt == stopTime)
        #expect(SessionService.activeSession(for: metric) == nil)
    }

    @Test
    func stopClampsToSessionStart() throws {
        let context = try makeContext()
        let metric = makeMetric(in: context)
        let id = try #require(metric.stableID)
        let start = Date.now.addingTimeInterval(-30)
        let session = Session(metric: metric, startedAt: start)
        context.insert(session)

        try WatchActionHandler.apply(
            WatchAction(
                kind: .stopTimer,
                metricID: id,
                timestamp: start.addingTimeInterval(-300)
            ),
            in: context
        )

        #expect(session.endedAt == start)
    }

    @Test
    func stopWithoutRunningSessionDoesNothing() throws {
        let context = try makeContext()
        let metric = makeMetric(in: context)
        let id = try #require(metric.stableID)

        try WatchActionHandler.apply(
            WatchAction(kind: .stopTimer, metricID: id),
            in: context
        )

        #expect(metric.sessions.isEmpty)
    }

    // MARK: - Log

    @Test
    func logValueCreatesCompletedBackdatedEntry() throws {
        let context = try makeContext()
        let metric = makeMetric(type: .count, in: context)
        let id = try #require(metric.stableID)
        let timestamp = Date.now.addingTimeInterval(-120)

        try WatchActionHandler.apply(
            WatchAction(
                kind: .logValue, metricID: id, value: 3, timestamp: timestamp
            ),
            in: context
        )

        let session = try #require(metric.sessions.first)
        #expect(session.value == 3)
        #expect(session.startedAt == timestamp)
        #expect(session.endedAt == timestamp)
        #expect(!session.isRunning)
    }

    // MARK: - Toggle (binary)

    @Test
    func toggleDayMarksBinaryDayDone() throws {
        let context = try makeContext()
        let metric = makeMetric(type: .binary, in: context)
        let id = try #require(metric.stableID)
        let timestamp = Date.now.addingTimeInterval(-120)

        try WatchActionHandler.apply(
            WatchAction(kind: .toggleDay, metricID: id, timestamp: timestamp),
            in: context
        )

        let session = try #require(metric.sessions.first)
        #expect(session.value == 1)
        #expect(session.startedAt == timestamp)
        #expect(!session.isRunning)
    }

    @Test
    func toggleDayClearsAnAlreadyDoneDay() throws {
        let context = try makeContext()
        let metric = makeMetric(type: .binary, in: context)
        let id = try #require(metric.stableID)

        try WatchActionHandler.apply(
            WatchAction(kind: .toggleDay, metricID: id),
            in: context
        )
        try WatchActionHandler.apply(
            WatchAction(kind: .toggleDay, metricID: id),
            in: context
        )

        #expect(metric.sessions.isEmpty)
    }

    @Test
    func unknownMetricIsIgnored() throws {
        let context = try makeContext()
        let metric = makeMetric(in: context)

        try WatchActionHandler.apply(
            WatchAction(kind: .startTimer, metricID: UUID()),
            in: context
        )

        #expect(metric.sessions.isEmpty)
    }

    // MARK: - Health-Linked

    @Test
    func healthLinkedMetricRejectsEveryAction() throws {
        let context = try makeContext()
        let metric = Metric(
            name: "Move",
            measurementType: .count,
            unit: "kcal",
            healthSource: .activeCalories
        )
        context.insert(metric)
        let id = try #require(metric.stableID)
        let kinds: [WatchAction.Kind] = [
            .startTimer, .stopTimer, .logValue, .toggleDay
        ]

        for kind in kinds {
            try WatchActionHandler.apply(
                WatchAction(kind: kind, metricID: id, value: 2),
                in: context
            )
        }

        #expect(metric.sessions.isEmpty)
    }
}

// MARK: - Snapshot Builder

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
}
