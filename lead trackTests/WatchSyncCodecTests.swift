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

    private func roundTripped(_ snapshot: WatchSnapshot) throws -> WatchSnapshot {
        let context = try #require(WatchSyncCodec.context(for: snapshot))
        return try #require(WatchSyncCodec.snapshot(from: context))
    }

    private func roundTripped(_ action: WatchAction) throws -> WatchAction {
        let message = try #require(WatchSyncCodec.message(for: action))
        return try #require(WatchSyncCodec.action(from: message))
    }

    @Test
    func snapshotRoundTripsThroughContext() throws {
        let snapshot = WatchSnapshot(metrics: [sampleMetric(todayTotal: 120)])
        let decoded = try roundTripped(snapshot)
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
        let decoded = try roundTripped(snapshot)
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
        let decoded = try roundTripped(action)
        #expect(decoded == action)
    }

    @Test
    func toggleActionRoundTripsThroughMessage() throws {
        let action = WatchAction(
            kind: .toggleDay,
            metricID: metricID,
            timestamp: Date(timeIntervalSince1970: 1_750_000_000)
        )
        let decoded = try roundTripped(action)
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
        let decoded = try roundTripped(snapshot)
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
        let decoded = try roundTripped(snapshot)
        #expect(decoded == snapshot)
        #expect(decoded.metrics.first?.countLogStyle == .incrementByOne)
    }

    @Test
    func buildStampSurvivesRoundTrip() throws {
        let builtAt = Date(timeIntervalSince1970: 1_750_000_000)
        let snapshot = WatchSnapshot(
            metrics: [sampleMetric()],
            day: Calendar.current.startOfDay(for: .now),
            builtAt: builtAt
        )
        let decoded = try roundTripped(snapshot)
        #expect(decoded.builtAt == builtAt)
    }

    @Test
    func unknownMeasurementTypeDegradesToOneReadOnlyMetric() throws {
        // A newer phone may ship measurement types this build doesn't know.
        // The snapshot must still decode — only that metric goes read-only.
        let payload = """
        {"metrics":[{"id":"11111111-2222-3333-4444-555555555555",
        "name":"Breathwork","measurementType":"somethingNew","todayTotal":3}]}
        """
        let data = try #require(payload.data(using: .utf8))
        let decoded = try JSONDecoder().decode(WatchSnapshot.self, from: data)
        let metric = try #require(decoded.metrics.first)
        #expect(metric.measurementType == nil)
        #expect(metric.measurementTypeRaw == "somethingNew")
        #expect(metric.displayIcon == "circle.dashed")
        #expect(metric.todayTotal == 3)
        #expect(!metric.hasDailyTarget)
    }

    @Test
    func measurementTypeStillEncodesUnderItsOriginalKey() throws {
        let context = try #require(
            WatchSyncCodec.context(for: WatchSnapshot(metrics: [sampleMetric()]))
        )
        let data = try #require(context["snapshot"] as? Data)
        let json = try #require(
            try JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        let metrics = try #require(json["metrics"] as? [[String: Any]])
        #expect(metrics.first?["measurementType"] as? String == "duration")
    }

    @Test
    func actionIDRoundTripsAndDistinguishesRetries() throws {
        let action = WatchAction(kind: .logValue, metricID: metricID, value: 1)
        let retry = WatchAction(kind: .logValue, metricID: metricID, value: 1)
        let decoded = try roundTripped(action)
        #expect(decoded.id == action.id)
        #expect(action.id != retry.id)
    }

    @Test
    func legacyActionWithoutIDStillDecodes() throws {
        let payload = """
        {"kind":"toggleDay","metricID":"11111111-2222-3333-4444-555555555555",
        "timestamp":1750000000}
        """
        let data = try #require(payload.data(using: .utf8))
        let decoded = try JSONDecoder().decode(
            WatchAction.self,
            from: data
        )
        #expect(decoded.id == nil)
        #expect(decoded.kind == .toggleDay)
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

    @Test
    func stopWhileIdleLeavesTotalsUntouched() throws {
        // A stale queued stop (the timer already ended elsewhere) must not
        // change today's total, only confirm nothing is running.
        let action = WatchAction(kind: .stopTimer, metricID: metricID)

        let result = WatchSnapshotReducer.applying(
            action, to: snapshot(todayTotal: 60)
        )

        let metric = try #require(result.metrics.first)
        #expect(metric.todayTotal == 60)
        #expect(metric.runningSince == nil)
    }

    @Test
    func stopBeforeStartClampsElapsedToZero() throws {
        let start = Date(timeIntervalSince1970: 1_750_000_000)
        let action = WatchAction(
            kind: .stopTimer,
            metricID: metricID,
            timestamp: start.addingTimeInterval(-300)
        )

        let result = WatchSnapshotReducer.applying(
            action, to: snapshot(runningSince: start, todayTotal: 60)
        )

        let metric = try #require(result.metrics.first)
        #expect(metric.runningSince == nil)
        #expect(metric.todayTotal == 60)
    }
}

// MARK: - Snapshot acceptance

struct WatchSnapshotAcceptanceTests {
    private func stamped(_ builtAt: Date?) -> WatchSnapshot {
        WatchSnapshot(metrics: [], day: nil, builtAt: builtAt)
    }

    @Test
    func olderOrIdenticalStampsAreRejected() {
        let held = Date(timeIntervalSince1970: 1_750_000_000)
        #expect(!WatchSnapshotReducer.shouldAccept(
            stamped(held.addingTimeInterval(-60)), over: stamped(held)
        ))
        #expect(!WatchSnapshotReducer.shouldAccept(
            stamped(held), over: stamped(held)
        ))
    }

    @Test
    func newerStampsAreAccepted() {
        let held = Date(timeIntervalSince1970: 1_750_000_000)
        #expect(WatchSnapshotReducer.shouldAccept(
            stamped(held.addingTimeInterval(60)), over: stamped(held)
        ))
    }

    @Test
    func missingStampsAreAlwaysAccepted() {
        let held = Date(timeIntervalSince1970: 1_750_000_000)
        #expect(WatchSnapshotReducer.shouldAccept(stamped(nil), over: stamped(held)))
        #expect(WatchSnapshotReducer.shouldAccept(stamped(held), over: stamped(nil)))
        #expect(WatchSnapshotReducer.shouldAccept(stamped(nil), over: stamped(nil)))
    }

    @Test
    func contentComparisonIgnoresTheBuildStamp() {
        let day = Calendar.current.startOfDay(for: .now)
        let earlier = WatchSnapshot(
            metrics: [], day: day, builtAt: Date(timeIntervalSince1970: 1_750_000_000)
        )
        let later = WatchSnapshot(
            metrics: [], day: day, builtAt: Date(timeIntervalSince1970: 1_750_000_600)
        )
        #expect(earlier.hasSameContent(as: later))
        #expect(earlier != later)

        var otherDay = later
        otherDay.day = day.addingTimeInterval(-86400)
        #expect(!earlier.hasSameContent(as: otherDay))
    }
}
