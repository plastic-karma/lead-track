import Foundation
import Testing
@testable import lead_track

struct WatchSyncCodecTests {
    private let metricID = UUID(
        uuidString: "11111111-2222-3333-4444-555555555555"
    ) ?? UUID()

    private func sampleMetric(
        runningSince: Date? = nil,
        todayTotal: Double = 0
    ) -> WatchMetricSnapshot {
        WatchMetricSnapshot(
            id: metricID,
            name: "Reading",
            measurementType: .duration,
            unit: nil,
            icon: "book",
            colorName: "sage",
            runningSince: runningSince,
            todayTotal: todayTotal
        )
    }

    @Test
    func snapshotRoundTripsThroughContext() throws {
        let snapshot = WatchSnapshot(metrics: [sampleMetric(todayTotal: 120)])
        let decoded = try #require(
            WatchSyncCodec.snapshot(from: WatchSyncCodec.context(for: snapshot))
        )
        #expect(decoded == snapshot)
    }

    @Test
    func actionRoundTripsThroughMessage() throws {
        let action = WatchAction(
            kind: .logValue,
            metricID: metricID,
            value: 3,
            timestamp: Date(timeIntervalSince1970: 1_750_000_000)
        )
        let decoded = try #require(
            WatchSyncCodec.action(from: WatchSyncCodec.message(for: action))
        )
        #expect(decoded == action)
    }

    @Test
    func decodingRejectsForeignPayloads() {
        #expect(WatchSyncCodec.snapshot(from: [:]) == nil)
        #expect(WatchSyncCodec.action(from: ["action": "junk"]) == nil)
    }

    @Test
    func refreshRequestIsRecognized() {
        #expect(WatchSyncCodec.isRefreshRequest(WatchSyncCodec.refreshRequest))
        #expect(!WatchSyncCodec.isRefreshRequest([:]))
    }
}

// MARK: - Reducer

struct WatchSnapshotReducerTests {
    private let metricID = UUID(
        uuidString: "11111111-2222-3333-4444-555555555555"
    ) ?? UUID()

    private func snapshot(
        runningSince: Date? = nil,
        todayTotal: Double = 0
    ) -> WatchSnapshot {
        WatchSnapshot(metrics: [
            WatchMetricSnapshot(
                id: metricID,
                name: "Reading",
                measurementType: .duration,
                unit: nil,
                icon: "book",
                colorName: nil,
                runningSince: runningSince,
                todayTotal: todayTotal
            )
        ])
    }

    @Test
    func startMarksMetricRunning() throws {
        let start = Date(timeIntervalSince1970: 1_750_000_000)
        let action = WatchAction(
            kind: .startTimer, metricID: metricID, timestamp: start
        )

        let result = WatchSnapshotReducer.applying(action, to: snapshot())

        let metric = try #require(result.metrics.first)
        #expect(metric.runningSince == start)
    }

    @Test
    func startKeepsEarlierRunningStart() {
        let original = Date(timeIntervalSince1970: 1_750_000_000)
        let action = WatchAction(
            kind: .startTimer,
            metricID: metricID,
            timestamp: original.addingTimeInterval(60)
        )

        let result = WatchSnapshotReducer.applying(
            action, to: snapshot(runningSince: original)
        )

        #expect(result.metrics.first?.runningSince == original)
    }

    @Test
    func stopAccumulatesElapsedTime() throws {
        let start = Date(timeIntervalSince1970: 1_750_000_000)
        let action = WatchAction(
            kind: .stopTimer,
            metricID: metricID,
            timestamp: start.addingTimeInterval(300)
        )

        let result = WatchSnapshotReducer.applying(
            action, to: snapshot(runningSince: start, todayTotal: 60)
        )

        let metric = try #require(result.metrics.first)
        #expect(metric.runningSince == nil)
        #expect(metric.todayTotal == 360)
    }

    @Test
    func logAddsValueToTodayTotal() {
        let action = WatchAction(
            kind: .logValue, metricID: metricID, value: 5
        )

        let result = WatchSnapshotReducer.applying(
            action, to: snapshot(todayTotal: 2)
        )

        #expect(result.metrics.first?.todayTotal == 7)
    }

    @Test
    func unknownMetricLeavesSnapshotUnchanged() {
        let action = WatchAction(kind: .startTimer, metricID: UUID())
        let original = snapshot(todayTotal: 9)

        let result = WatchSnapshotReducer.applying(action, to: original)

        #expect(result == original)
    }
}
