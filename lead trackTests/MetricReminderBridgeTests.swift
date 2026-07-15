import Foundation
import Testing
@testable import lead_track

/// The reminder bridge's legacy-mirror invariant: every write through
/// `applyReminderSchedule` mirrors the first fixed time into the legacy
/// `reminderTime` field (which pre-multi-time builds still read), so a
/// writer bypassing the bridge — or a bridge regression — cannot silently
/// desynchronize the two.
struct MetricReminderBridgeTests {
    @Test
    func applyMirrorsFirstFixedTimeIntoLegacyField() {
        let metric = Metric(name: "Reading", measurementType: .duration)
        var schedule = ReminderSchedule.makeDefault()
        let nine = ReminderSchedule.time(hour: 9)
        let noon = ReminderSchedule.time(hour: 12)
        schedule.fixedTimes = [nine, noon]

        metric.applyReminderSchedule(schedule)

        #expect(metric.reminderTimes == [nine, noon])
        #expect(metric.reminderTime == nine)
    }

    @Test
    func clearingTheScheduleClearsTheLegacyMirror() {
        let metric = Metric(name: "Reading", measurementType: .duration)
        metric.applyReminderSchedule(.makeDefault())

        metric.applyReminderSchedule(nil)

        #expect(metric.reminderTime == nil)
        #expect(metric.reminderTimes.isEmpty)
    }
}
