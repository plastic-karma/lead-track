import Foundation
import Testing
@testable import lead_track

struct CountdownTimerTests {
    private let start = Date(timeIntervalSince1970: 1_750_000_000)

    @Test
    func metricWithoutDurationCountsUp() {
        let metric = Metric(name: "Reading")
        #expect(!metric.countsDown)
        let session = Session(metric: metric, startedAt: start)
        #expect(metric.countdownInterval(for: session) == nil)
    }

    @Test
    func zeroDurationDoesNotCountDown() {
        let metric = Metric(name: "Reading")
        metric.countdownDuration = 0
        #expect(!metric.countsDown)
        let session = Session(metric: metric, startedAt: start)
        #expect(metric.countdownInterval(for: session) == nil)
    }

    @Test
    func countdownIntervalSpansTheTargetFromSessionStart() throws {
        let metric = Metric(name: "Focus")
        metric.countdownDuration = 1500
        #expect(metric.countsDown)
        let session = Session(metric: metric, startedAt: start)

        let interval = try #require(metric.countdownInterval(for: session))
        #expect(interval.lowerBound == start)
        #expect(interval.upperBound == start.addingTimeInterval(1500))
    }

    @Test
    func snapshotIntervalRequiresRunningTimer() {
        let idle = WatchMetricSnapshot(
            id: UUID(),
            name: "Focus",
            measurementType: .duration,
            unit: nil,
            icon: nil,
            colorName: nil,
            runningSince: nil,
            todayTotal: 0,
            countdownDuration: 1500
        )
        #expect(idle.countdownInterval == nil)
    }

    @Test
    func runningSnapshotIntervalSpansTheTarget() throws {
        let running = WatchMetricSnapshot(
            id: UUID(),
            name: "Focus",
            measurementType: .duration,
            unit: nil,
            icon: nil,
            colorName: nil,
            runningSince: start,
            todayTotal: 0,
            countdownDuration: 1500
        )
        let interval = try #require(running.countdownInterval)
        #expect(interval.lowerBound == start)
        #expect(interval.upperBound == start.addingTimeInterval(1500))
    }
}
