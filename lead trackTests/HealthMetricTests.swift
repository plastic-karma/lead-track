import Foundation
import Testing
@testable import lead_track

// MARK: - Source Catalog

struct HealthDataSourceTests {
    @Test
    func rawValuesStayStable() {
        // Persisted in the store and in watch snapshots — renaming a case
        // would orphan every existing health metric.
        #expect(HealthDataSource.activeCalories.rawValue == "activeCalories")
        #expect(HealthDataSource.exerciseMinutes.rawValue == "exerciseMinutes")
        #expect(HealthDataSource.standMinutes.rawValue == "standMinutes")
        #expect(HealthDataSource.workoutCount.rawValue == "workoutCount")
        #expect(HealthDataSource.workoutMinutes.rawValue == "workoutMinutes")
    }

    @Test
    func minuteSourcesReadAsDurations() {
        #expect(HealthDataSource.exerciseMinutes.measurementType == .duration)
        #expect(HealthDataSource.standMinutes.measurementType == .duration)
        #expect(HealthDataSource.workoutMinutes.measurementType == .duration)
        #expect(HealthDataSource.exerciseMinutes.defaultUnit == nil)
        #expect(HealthDataSource.standMinutes.defaultUnit == nil)
        #expect(HealthDataSource.workoutMinutes.defaultUnit == nil)
    }

    @Test
    func countSourcesCarryTheirUnits() {
        #expect(HealthDataSource.activeCalories.measurementType == .count)
        #expect(HealthDataSource.activeCalories.defaultUnit == "kcal")
        #expect(HealthDataSource.workoutCount.measurementType == .count)
        #expect(HealthDataSource.workoutCount.defaultUnit == "workouts")
    }

    @Test
    func everySourcePresentsItself() {
        for source in HealthDataSource.allCases {
            #expect(!source.displayName.isEmpty)
            #expect(!source.explanation.isEmpty)
            #expect(!source.defaultIcon.isEmpty)
        }
    }
}

// MARK: - Metric Link

struct MetricHealthLinkTests {
    @Test
    func healthMetricRoundTripsItsSource() {
        let metric = Metric(
            name: "Move",
            measurementType: .count,
            unit: "kcal",
            healthSource: .activeCalories
        )
        #expect(metric.isHealthLinked)
        #expect(metric.healthSource == .activeCalories)
    }

    @Test
    func plainMetricIsNotHealthLinked() {
        let metric = Metric(name: "Reading")
        #expect(!metric.isHealthLinked)
        #expect(metric.healthSource == nil)
    }

    @Test
    func unknownStoredSourceStillCountsAsLinked() {
        // A store written by a newer app version must not fall back to
        // manual logging just because this build can't name the source.
        let metric = Metric(name: "Future")
        metric.healthSourceRaw = "somethingNew"
        #expect(metric.isHealthLinked)
        #expect(metric.healthSource == nil)
    }
}

// MARK: - Mirror Window

struct HealthMirrorWindowTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        return calendar
    }

    private let reference = Date(timeIntervalSince1970: 1_750_000_000)

    @Test
    func windowEndsOnReferenceDayAndSpansBackward() throws {
        let window = HealthDailyMirror.window(
            days: 30, endingOn: reference, calendar: calendar
        )
        #expect(window.count == 30)
        let first = try #require(window.first)
        let last = try #require(window.last)
        #expect(last == calendar.startOfDay(for: reference))
        let span = calendar.dateComponents([.day], from: first, to: last).day
        #expect(span == 29)
    }

    @Test
    func windowIsOrderedOldestFirst() {
        let window = HealthDailyMirror.window(
            days: 7, endingOn: reference, calendar: calendar
        )
        #expect(window == window.sorted())
    }
}

// MARK: - Mirror Planning

struct HealthMirrorPlanTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        return calendar
    }

    private func days(_ count: Int) -> [Date] {
        HealthDailyMirror.window(
            days: count,
            endingOn: Date(timeIntervalSince1970: 1_750_000_000),
            calendar: calendar
        )
    }

    @Test
    func freshDataInsertsOnlyNonZeroDays() throws {
        let window = days(3)
        let oldest = try #require(window.first)
        let newest = try #require(window.last)

        let operations = HealthDailyMirror.plan(
            window: window,
            fetched: [oldest: 250, newest: 0],
            existing: [:]
        )

        #expect(operations == [.insert(day: oldest, value: 250)])
    }

    @Test
    func matchingValuesPlanNothing() throws {
        let day = try #require(days(2).first)

        let operations = HealthDailyMirror.plan(
            window: days(2),
            fetched: [day: 1800],
            existing: [day: [1800]]
        )

        #expect(operations.isEmpty)
    }

    @Test
    func changedValueUpdatesInPlace() throws {
        let day = try #require(days(2).first)

        let operations = HealthDailyMirror.plan(
            window: days(2),
            fetched: [day: 2400],
            existing: [day: [1800]]
        )

        #expect(operations == [.update(day: day, value: 2400)])
    }

    @Test
    func vanishedValueDeletesTheDay() throws {
        let day = try #require(days(2).first)

        let operations = HealthDailyMirror.plan(
            window: days(2),
            fetched: [:],
            existing: [day: [1800]]
        )

        #expect(operations == [.delete(day: day)])
    }

    @Test
    func duplicateSessionsRebuildTheDay() throws {
        let day = try #require(days(1).first)

        let operations = HealthDailyMirror.plan(
            window: days(1),
            fetched: [day: 900],
            existing: [day: [600, 600]]
        )

        #expect(operations == [.delete(day: day), .insert(day: day, value: 900)])
    }

    @Test
    func duplicateSessionsOnAnEmptyDayJustClear() throws {
        let day = try #require(days(1).first)

        let operations = HealthDailyMirror.plan(
            window: days(1),
            fetched: [:],
            existing: [day: [600, 300]]
        )

        #expect(operations == [.delete(day: day)])
    }

    @Test
    func daysOutsideTheWindowAreUntouched() throws {
        let window = days(2)
        let outside = try #require(
            calendar.date(byAdding: .day, value: -10, to: window[0])
        )

        let operations = HealthDailyMirror.plan(
            window: window,
            fetched: [outside: 999],
            existing: [outside: [1]]
        )

        #expect(operations.isEmpty)
    }
}

// MARK: - Watch Read-Only

struct HealthWatchBehaviorTests {
    private let metricID = UUID(
        uuidString: "99999999-8888-7777-6666-555555555555"
    ) ?? UUID()

    private func healthSnapshot(todayTotal: Double = 500) -> WatchSnapshot {
        WatchSnapshot(metrics: [
            WatchMetricSnapshot(
                id: metricID,
                name: "Move",
                measurementType: .count,
                unit: "kcal",
                icon: "flame",
                colorName: nil,
                todayTotal: todayTotal,
                healthSourceRaw: HealthDataSource.activeCalories.rawValue
            )
        ])
    }

    @Test
    func reducerIgnoresEveryActionKind() {
        let original = healthSnapshot()
        let kinds: [WatchAction.Kind] = [
            .startTimer, .stopTimer, .logValue, .toggleDay
        ]
        for kind in kinds {
            let action = WatchAction(kind: kind, metricID: metricID, value: 3)
            #expect(WatchSnapshotReducer.applying(action, to: original) == original)
        }
    }

    @Test
    func healthSourceSurvivesCodecRoundTrip() throws {
        let snapshot = healthSnapshot()
        let decoded = try #require(
            WatchSyncCodec.snapshot(from: WatchSyncCodec.context(for: snapshot))
        )
        #expect(decoded == snapshot)
        #expect(decoded.metrics.first?.isHealthLinked == true)
    }

    @Test
    func snapshotsFromOlderAppVersionsStillDecode() throws {
        let legacy = """
        {"metrics":[{"id":"11111111-2222-3333-4444-555555555555",\
        "name":"Reading","measurementType":"duration","todayTotal":120}]}
        """
        let decoded = try JSONDecoder().decode(
            WatchSnapshot.self, from: Data(legacy.utf8)
        )
        #expect(decoded.metrics.first?.isHealthLinked == false)
    }
}
