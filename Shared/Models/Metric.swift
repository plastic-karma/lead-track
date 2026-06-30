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
    var metricDescription: String?
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

    #if canImport(SwiftData)
    @Relationship(deleteRule: .cascade, inverse: \Project.metric)
    #endif
    var projects: [Project] = []

    #if canImport(SwiftData)
    @Relationship(deleteRule: .cascade, inverse: \Session.metric)
    #endif
    var sessions: [Session] = []

    // Back-array for the many-to-many with `Aspiration`. Plain (no macro): the
    // `inverse:` is declared on `Aspiration` only. Defaults empty, so every
    // existing metric reads as "no aspirations" with no migration.
    var aspirations: [Aspiration] = []

    init(
        name: String,
        measurementType: MeasurementType = .duration,
        unit: String? = nil,
        icon: String? = nil,
        colorName: String? = nil,
        metricDescription: String? = nil,
        createdAt: Date = .now
    ) {
        stableID = UUID()
        self.name = name
        self.metricDescription = metricDescription
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

// MARK: - Display Icon

extension Metric {
    /// The SF Symbol every surface shows for the metric, with the shared
    /// fallback for metrics saved before icons existed.
    var displayIcon: String {
        icon ?? "clock"
    }
}

// MARK: - Description

extension Metric {
    /// Normalizes free-text description input: trims surrounding whitespace and
    /// collapses an all-whitespace string to nil, so a blank description is
    /// stored as "no description" rather than an empty string.
    static func normalizedDescription(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
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
