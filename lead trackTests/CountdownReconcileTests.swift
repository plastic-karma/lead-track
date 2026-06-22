import Foundation
import SwiftData
import Testing
@testable import lead_track

@MainActor
struct CountdownReconcileTests {
    private func makeContext() throws -> ModelContext {
        try ModelContext(SharedModelContainer.create(inMemoryOnly: true))
    }

    private func makeCountdownMetric(
        _ seconds: TimeInterval,
        in context: ModelContext
    ) -> Metric {
        let metric = Metric(name: "Focus")
        metric.countdownDuration = seconds
        context.insert(metric)
        return metric
    }

    @Test
    func elapsedCountdownStopsAtItsEnd() throws {
        let context = try makeContext()
        let metric = makeCountdownMetric(60, in: context)
        let start = Date.now.addingTimeInterval(-120)
        let session = Session(metric: metric, startedAt: start)
        context.insert(session)

        let changed = SessionService.reconcileCountdowns(in: context)

        #expect(changed)
        #expect(session.endedAt == start.addingTimeInterval(60))
        #expect(!session.isRunning)
    }

    @Test
    func runningCountdownBeforeEndKeepsGoing() throws {
        let context = try makeContext()
        let metric = makeCountdownMetric(600, in: context)
        let session = Session(
            metric: metric, startedAt: .now.addingTimeInterval(-60)
        )
        context.insert(session)

        let changed = SessionService.reconcileCountdowns(in: context)

        #expect(!changed)
        #expect(session.isRunning)
    }

    @Test
    func countUpTimerIsNeverAutoStopped() throws {
        let context = try makeContext()
        let metric = Metric(name: "Reading")
        context.insert(metric)
        let session = Session(
            metric: metric, startedAt: .now.addingTimeInterval(-9999)
        )
        context.insert(session)

        let changed = SessionService.reconcileCountdowns(in: context)

        #expect(!changed)
        #expect(session.isRunning)
    }

    @Test
    func nextCountdownEndReturnsSoonest() throws {
        let context = try makeContext()
        let soon = makeCountdownMetric(60, in: context)
        let later = makeCountdownMetric(600, in: context)
        let now = Date.now
        context.insert(Session(metric: soon, startedAt: now))
        context.insert(Session(metric: later, startedAt: now))

        let next = try #require(SessionService.nextCountdownEnd(in: context))

        #expect(abs(next.timeIntervalSince(now.addingTimeInterval(60))) < 0.001)
    }

    @Test
    func nextCountdownEndIsNilWithoutCountdowns() throws {
        let context = try makeContext()
        let metric = Metric(name: "Reading")
        context.insert(metric)
        context.insert(Session(metric: metric, startedAt: .now))

        #expect(SessionService.nextCountdownEnd(in: context) == nil)
    }
}
