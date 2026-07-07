import Foundation
import Testing
@testable import lead_track

struct WatchSyncCodecTests {
    private let metricID = UUID(
        uuidString: "11111111-2222-3333-4444-555555555555"
    ) ?? UUID()

    private func sampleMetric(
        runningSince: Date? = nil,
        todayTotal: Double = 0,
        dailyGoal: Double? = nil,
        excludedWeekdays: [Int]? = nil,
        countdownDuration: TimeInterval? = nil,
        countLogStyleRaw: String? = nil
    ) -> WatchMetricSnapshot {
        WatchMetricSnapshot(
            id: metricID,
            name: "Reading",
            measurementType: .duration,
            unit: nil,
            icon: "book",
            colorName: "sage",
            runningSince: runningSince,
            todayTotal: todayTotal,
            dailyGoal: dailyGoal,
            excludedWeekdays: excludedWeekdays,
            countdownDuration: countdownDuration,
            countLogStyleRaw: countLogStyleRaw
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
    func countdownSurvivesRoundTrip() throws {
        let snapshot = WatchSnapshot(metrics: [
            sampleMetric(
                runningSince: Date(timeIntervalSince1970: 1_750_000_000),
                countdownDuration: 1500
            )
        ])
        let decoded = try #require(
            WatchSyncCodec.snapshot(from: WatchSyncCodec.context(for: snapshot))
        )
        #expect(decoded == snapshot)
        #expect(decoded.metrics.first?.countdownDuration == 1500)
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
    func toggleActionRoundTripsThroughMessage() throws {
        let action = WatchAction(
            kind: .toggleDay,
            metricID: metricID,
            timestamp: Date(timeIntervalSince1970: 1_750_000_000)
        )
        let decoded = try #require(
            WatchSyncCodec.action(from: WatchSyncCodec.message(for: action))
        )
        #expect(decoded == action)
    }

    @Test
    func goalFieldsAndDaySurviveRoundTrip() throws {
        let day = Calendar.current.startOfDay(for: .now)
        let snapshot = WatchSnapshot(
            metrics: [
                sampleMetric(todayTotal: 120, dailyGoal: 1800, excludedWeekdays: [1, 7])
            ],
            day: day
        )
        let decoded = try #require(
            WatchSyncCodec.snapshot(from: WatchSyncCodec.context(for: snapshot))
        )
        #expect(decoded == snapshot)
        #expect(decoded.day == day)
        #expect(decoded.metrics.first?.dailyGoal == 1800)
        #expect(decoded.metrics.first?.excludedWeekdays == [1, 7])
    }

    @Test
    func countLogStyleSurvivesRoundTrip() throws {
        let snapshot = WatchSnapshot(metrics: [
            sampleMetric(countLogStyleRaw: CountLogStyle.incrementByOne.rawValue)
        ])
        let decoded = try #require(
            WatchSyncCodec.snapshot(from: WatchSyncCodec.context(for: snapshot))
        )
        #expect(decoded == snapshot)
        #expect(decoded.metrics.first?.countLogStyle == .incrementByOne)
    }

    @Test
    func legacyCacheWithoutGoalFieldsStillDecodes() throws {
        let legacy = """
        {"metrics":[{"id":"11111111-2222-3333-4444-555555555555",
        "name":"Reading","measurementType":"duration","todayTotal":120}]}
        """
        let data = try #require(legacy.data(using: .utf8))
        let decoded = try JSONDecoder().decode(WatchSnapshot.self, from: data)
        #expect(decoded.day == nil)
        let metric = try #require(decoded.metrics.first)
        #expect(metric.name == "Reading")
        #expect(metric.todayTotal == 120)
        #expect(metric.dailyGoal == nil)
        #expect(metric.excludedWeekdays == nil)
        #expect(metric.countLogStyle == .askAmount)
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
        todayTotal: Double = 0,
        day: Date? = nil
    ) -> WatchSnapshot {
        WatchSnapshot(
            metrics: [
                WatchMetricSnapshot(
                    id: metricID,
                    name: "Reading",
                    measurementType: .duration,
                    unit: nil,
                    icon: "book",
                    colorName: nil,
                    runningSince: runningSince,
                    todayTotal: todayTotal,
                    countdownDuration: nil
                )
            ],
            day: day
        )
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
    func toggleDayMarksDoneFromZero() {
        let action = WatchAction(kind: .toggleDay, metricID: metricID)

        let result = WatchSnapshotReducer.applying(
            action, to: snapshot(todayTotal: 0)
        )

        #expect(result.metrics.first?.todayTotal == 1)
    }

    @Test
    func toggleDayClearsWhenAlreadyDone() {
        let action = WatchAction(kind: .toggleDay, metricID: metricID)

        let result = WatchSnapshotReducer.applying(
            action, to: snapshot(todayTotal: 1)
        )

        #expect(result.metrics.first?.todayTotal == 0)
    }

    @Test
    func unknownMetricLeavesSnapshotUnchanged() {
        let action = WatchAction(kind: .startTimer, metricID: UUID())
        let original = snapshot(todayTotal: 9)

        let result = WatchSnapshotReducer.applying(action, to: original)

        #expect(result == original)
    }

    @Test
    func sameDayActionPreservesTheDayStamp() {
        let day = Calendar.current.startOfDay(for: .now)
        let action = WatchAction(kind: .logValue, metricID: metricID, value: 2)

        let result = WatchSnapshotReducer.applying(
            action, to: snapshot(todayTotal: 1, day: day)
        )

        #expect(result.day == day)
        #expect(result.metrics.first?.todayTotal == 3)
    }

    @Test
    func crossDayActionZeroesTotalsAndRestamps() throws {
        let calendar = Calendar.current
        let yesterday = try #require(
            calendar.date(byAdding: .day, value: -1, to: .now)
        )
        let action = WatchAction(kind: .logValue, metricID: metricID, value: 2)

        let result = WatchSnapshotReducer.applying(
            action,
            to: snapshot(todayTotal: 9, day: calendar.startOfDay(for: yesterday))
        )

        #expect(result.day == calendar.startOfDay(for: action.timestamp))
        #expect(result.metrics.first?.todayTotal == 2)
    }

    @Test
    func snapshotWithoutDayStampIsNeverRolledForward() {
        let action = WatchAction(kind: .logValue, metricID: metricID, value: 2)

        let result = WatchSnapshotReducer.applying(
            action, to: snapshot(todayTotal: 9)
        )

        #expect(result.day == nil)
        #expect(result.metrics.first?.todayTotal == 11)
    }
}
