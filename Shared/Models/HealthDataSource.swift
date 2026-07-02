import Foundation

/// The Apple Health figure a health-linked metric mirrors. Health-linked
/// metrics never record sessions by hand; the phone fills one value-session
/// per day from HealthKit instead (see `HealthDailyMirror`), so every surface
/// downstream — goals, streaks, charts, watch, widgets — reads them like any
/// other metric.
enum HealthDataSource: String, Codable, CaseIterable {
    case activeCalories
    case exerciseMinutes
    case standMinutes
    case workoutCount
    case workoutMinutes
}

extension HealthDataSource {
    var displayName: String {
        switch self {
        case .activeCalories: "Active Calories"
        case .exerciseMinutes: "Exercise Minutes"
        case .standMinutes: "Stand Minutes"
        case .workoutCount: "Workouts"
        case .workoutMinutes: "Workout Time"
        }
    }

    /// One-line explanation shown while picking a source, so ring names and
    /// workout figures aren't confused with each other.
    var explanation: String {
        switch self {
        case .activeCalories: "Calories burned through movement — your Move ring."
        case .exerciseMinutes: "Minutes of brisk activity — your Exercise ring."
        case .standMinutes: "Minutes spent standing and moving around."
        case .workoutCount: "How many workouts you log each day."
        case .workoutMinutes: "Total time across your logged workouts."
        }
    }

    /// How mirrored values are displayed and aggregated. Minute-based sources
    /// read as durations (stored in seconds, like timer sessions); the rest
    /// read as counts.
    var measurementType: MeasurementType {
        switch self {
        case .activeCalories, .workoutCount: .count
        case .exerciseMinutes, .standMinutes, .workoutMinutes: .duration
        }
    }

    /// The unit label for count-style sources; duration sources format as time.
    var defaultUnit: String? {
        switch self {
        case .activeCalories: "kcal"
        case .workoutCount: "workouts"
        case .exerciseMinutes, .standMinutes, .workoutMinutes: nil
        }
    }

    var defaultIcon: String {
        switch self {
        case .activeCalories: "flame"
        case .exerciseMinutes: "figure.run"
        case .standMinutes: "figure.stand"
        case .workoutCount: "trophy"
        case .workoutMinutes: "stopwatch"
        }
    }
}
