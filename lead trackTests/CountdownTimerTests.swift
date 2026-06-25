import Foundation
import Testing
@testable import lead_track

struct CountdownTimerTests {
    private let start = Date(timeIntervalSince1970: 1_750_000_000)

    @Test
    func sessionWithoutDurationCountsUp() {
        let session = Session(startedAt: start)
        #expect(!session.countsDown)
        #expect(session.countdownInterval == nil)
    }

    @Test
    func zeroDurationDoesNotCountDown() {
        let session = Session(startedAt: start, countdownDuration: 0)
        #expect(!session.countsDown)
        #expect(session.countdownInterval == nil)
    }

    @Test
    func countdownIntervalSpansTheTargetFromSessionStart() throws {
        let session = Session(startedAt: start, countdownDuration: 1500)
        #expect(session.countsDown)

        let interval = try #require(session.countdownInterval)
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
