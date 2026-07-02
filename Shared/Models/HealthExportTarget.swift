import Foundation

/// The Apple Health record a timer metric's sessions are written back as.
/// Opt-in per metric and only for duration metrics: each completed session
/// becomes one mindful session or one workout covering the same interval.
/// The reverse of `HealthDataSource` — that mirrors Health into a metric;
/// this sends a metric's own recordings to Health.
enum HealthExportTarget: String, Codable, CaseIterable {
    case mindfulness
    case workout
}

extension HealthExportTarget {
    var displayName: String {
        switch self {
        case .mindfulness: "Mindful Minutes"
        case .workout: "Workout Minutes"
        }
    }

    /// One-line explanation shown while picking a target, so the user knows
    /// what will appear in the Health app.
    var explanation: String {
        switch self {
        case .mindfulness: "Each session is saved as a mindful session."
        case .workout: "Each session is saved as a workout."
        }
    }
}
