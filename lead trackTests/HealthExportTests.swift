import Foundation
import Testing
@testable import lead_track

// MARK: - Target Catalog

struct HealthExportTargetTests {
    @Test
    func rawValuesStayStable() {
        // Persisted in the store — renaming a case would silently switch
        // every exporting metric off.
        #expect(HealthExportTarget.mindfulness.rawValue == "mindfulness")
        #expect(HealthExportTarget.workout.rawValue == "workout")
    }

    @Test
    func everyTargetPresentsItself() {
        for target in HealthExportTarget.allCases {
            #expect(!target.displayName.isEmpty)
            #expect(!target.explanation.isEmpty)
        }
    }
}

// MARK: - Metric Switch

struct MetricHealthExportTests {
    @Test
    func onlyHandRecordedTimerMetricsSupportExport() {
        #expect(Metric(name: "Read", measurementType: .duration).supportsHealthExport)
        #expect(!Metric(name: "Pages", measurementType: .count).supportsHealthExport)
        #expect(!Metric(name: "Floss", measurementType: .binary).supportsHealthExport)
        let mirrored = Metric(
            name: "Workouts",
            measurementType: .duration,
            healthSource: .workoutMinutes
        )
        #expect(!mirrored.supportsHealthExport)
    }

    @Test
    func enablingStampsTheSwitchOnDate() {
        let metric = Metric(name: "Meditate")
        let enabled = Date(timeIntervalSince1970: 1_000)
        metric.setHealthExport(.mindfulness, at: enabled)
        #expect(metric.healthExportTarget == .mindfulness)
        #expect(metric.healthExportEnabledAt == enabled)
    }

    @Test
    func retargetingKeepsTheOriginalStamp() {
        let metric = Metric(name: "Meditate")
        let enabled = Date(timeIntervalSince1970: 1_000)
        metric.setHealthExport(.mindfulness, at: enabled)
        metric.setHealthExport(.workout, at: enabled.addingTimeInterval(500))
        #expect(metric.healthExportTarget == .workout)
        #expect(metric.healthExportEnabledAt == enabled)
    }

    @Test
    func disablingClearsTheSwitch() {
        let metric = Metric(name: "Meditate")
        metric.setHealthExport(.workout, at: .now)
        metric.setHealthExport(nil)
        #expect(metric.healthExportTarget == nil)
        #expect(metric.healthExportEnabledAt == nil)
    }
}

// MARK: - Export Plan

struct HealthSessionExportTests {
    private let enabled = Date(timeIntervalSince1970: 10_000)

    private func timerSession(startedAt: Date, length: TimeInterval) -> Session {
        Session(
            startedAt: startedAt,
            endedAt: startedAt.addingTimeInterval(length)
        )
    }

    @Test
    func timerSessionSpansStartToEnd() {
        let session = timerSession(startedAt: enabled, length: 600)
        let interval = HealthSessionExport.interval(of: session)
        #expect(interval == DateInterval(start: enabled, duration: 600))
    }

    @Test
    func valueSessionSpansItsValueFromItsStart() {
        // Imported sessions carry an explicit length instead of an end date.
        let session = Session(startedAt: enabled, endedAt: enabled, value: 300)
        let interval = HealthSessionExport.interval(of: session)
        #expect(interval == DateInterval(start: enabled, duration: 300))
    }

    @Test
    func runningAndEmptySessionsHaveNoInterval() {
        #expect(HealthSessionExport.interval(of: Session(startedAt: enabled)) == nil)
        let empty = timerSession(startedAt: enabled, length: 0)
        #expect(HealthSessionExport.interval(of: empty) == nil)
    }

    @Test
    func pendingKeepsOnlyUnsentSessionsSinceTheSwitchOn() {
        let sent = timerSession(startedAt: enabled.addingTimeInterval(60), length: 60)
        sent.healthExportedAt = .now
        let before = timerSession(startedAt: enabled.addingTimeInterval(-60), length: 60)
        let running = Session(startedAt: enabled.addingTimeInterval(120))
        let due = timerSession(startedAt: enabled.addingTimeInterval(180), length: 60)
        let sessions = [due, sent, before, running]
        let pending = HealthSessionExport.pending(in: sessions, enabledAt: enabled)
        #expect(pending.count == 1)
        #expect(pending.first === due)
    }

    @Test
    func pendingSortsOldestFirst() {
        let later = timerSession(startedAt: enabled.addingTimeInterval(600), length: 60)
        let earlier = timerSession(startedAt: enabled, length: 60)
        let pending = HealthSessionExport.pending(
            in: [later, earlier],
            enabledAt: enabled
        )
        #expect(pending.first === earlier)
        #expect(pending.last === later)
    }

    @Test
    func nothingIsPendingWhileExportIsOff() {
        let session = timerSession(startedAt: enabled, length: 60)
        #expect(HealthSessionExport.pending(in: [session], enabledAt: nil).isEmpty)
    }
}
