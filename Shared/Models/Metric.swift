import Foundation
#if canImport(SwiftData)
import SwiftData
#endif

#if canImport(SwiftData)
@Model
#endif
final class Metric {
    #if canImport(SwiftData)
    #Unique<Metric>([\.stableID])
    #endif
    var stableID: UUID?
    var name: String
    var measurementType: MeasurementType
    var unit: String?
    var icon: String?
    var colorName: String?
    var createdAt: Date
    var dailyGoal: TimeInterval?
    var weeklyGoal: TimeInterval?
    var reminderTime: Date?
    var streakAlertTime: Date?
    var excludedWeekdays: [Int] = []
    /// When set on a duration metric, its timer counts down from this many
    /// seconds instead of up. Display-only: the recorded session length is
    /// still the real elapsed time.
    var countdownDuration: TimeInterval?

    #if canImport(SwiftData)
    @Relationship(deleteRule: .cascade, inverse: \Project.metric)
    #endif
    var projects: [Project] = []

    #if canImport(SwiftData)
    @Relationship(deleteRule: .cascade, inverse: \Session.metric)
    #endif
    var sessions: [Session] = []

    init(
        name: String,
        measurementType: MeasurementType = .duration,
        unit: String? = nil,
        icon: String? = nil,
        colorName: String? = nil,
        createdAt: Date = .now
    ) {
        stableID = UUID()
        self.name = name
        self.measurementType = measurementType
        self.unit = unit
        self.icon = icon
        self.colorName = colorName
        self.createdAt = createdAt
    }
}

// MARK: - Default Project

extension Metric {
    /// The active project that new recordings are auto-assigned to, if any.
    /// At most one active project per metric can be the default.
    var defaultProject: Project? {
        projects.first { $0.isDefault && $0.status == .active }
    }
}

// MARK: - Countdown

extension Metric {
    /// Whether this metric's timer counts down from a fixed target.
    var countsDown: Bool {
        (countdownDuration ?? 0) > 0
    }

    /// The range a running countdown session animates across — start to the
    /// instant it reaches zero — or nil for a count-up metric.
    func countdownInterval(for session: Session) -> ClosedRange<Date>? {
        guard let target = countdownDuration, target > 0 else { return nil }
        return session.startedAt ... session.startedAt.addingTimeInterval(target)
    }
}

// MARK: - Display Icon

extension Metric {
    /// The SF Symbol every surface shows for the metric, with the shared
    /// fallback for metrics saved before icons existed.
    var displayIcon: String {
        icon ?? "clock"
    }
}

// MARK: - Lookup

#if canImport(SwiftData)
extension Metric {
    /// Fetches the metric carrying this stable identity — the ID that watch
    /// actions, widget configurations, and intents reference.
    static func find(
        stableID id: UUID,
        in context: ModelContext
    ) throws -> Metric? {
        var descriptor = FetchDescriptor<Metric>(
            predicate: #Predicate { $0.stableID == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}
#endif

// MARK: - Daily Goal Schedule

extension Metric {
    /// Weekday numbers (1 = Sunday ... 7 = Saturday) excluded from the daily goal.
    var excludedWeekdaySet: Set<Int> {
        Set(excludedWeekdays)
    }

    /// Whether the daily goal applies on the given date's weekday.
    func isGoalDay(on date: Date, calendar: Calendar = .current) -> Bool {
        !excludedWeekdays.contains(calendar.component(.weekday, from: date))
    }
}
