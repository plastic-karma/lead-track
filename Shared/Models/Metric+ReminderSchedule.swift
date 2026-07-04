import Foundation

/// Bridges the metric's stored reminder fields to the `ReminderSchedule`
/// value type the editor and scheduler work with. Kept in its own file so
/// `Metric.swift` stays focused on storage.
extension Metric {
    /// The daily-reminder configuration, or nil when the reminder is off. Folds
    /// the legacy single `reminderTime` into fixed mode, so a pre-feature store
    /// keeps its one reminder.
    var reminderSchedule: ReminderSchedule? {
        guard reminderIsOn else { return nil }
        return ReminderSchedule(
            mode: reminderUsesRandom ? .random : .fixed,
            fixedTimes: reminderFixedTimes,
            rangeStart: reminderRandomStart ?? ReminderSchedule.time(hour: 8),
            rangeEnd: reminderRandomEnd ?? ReminderSchedule.time(hour: 20),
            count: reminderRandomCount
        )
    }

    /// Persists an edited reminder configuration, or clears it when nil.
    /// Mirrors the first fixed time into the legacy `reminderTime` so an older
    /// app build still shows a reminder.
    func applyReminderSchedule(_ schedule: ReminderSchedule?) {
        guard let schedule = schedule else {
            clearReminderSchedule()
            return
        }
        let times = schedule.normalizedFixedTimes
        reminderTimes = times
        reminderTime = times.first
        reminderRandomStart = schedule.rangeStart
        reminderRandomEnd = schedule.rangeEnd
        reminderRandomCount = schedule.clampedCount
        reminderUsesRandom = schedule.mode == .random
    }

    private var reminderIsOn: Bool {
        if reminderUsesRandom {
            return reminderRandomStart != nil && reminderRandomEnd != nil
        }
        return !reminderFixedTimes.isEmpty
    }

    private var reminderFixedTimes: [Date] {
        if !reminderTimes.isEmpty {
            return reminderTimes
        }
        return reminderTime.map { [$0] } ?? []
    }

    private func clearReminderSchedule() {
        reminderTimes = []
        reminderTime = nil
        reminderRandomStart = nil
        reminderRandomEnd = nil
        reminderUsesRandom = false
    }
}
