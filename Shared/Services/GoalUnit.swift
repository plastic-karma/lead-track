import Foundation

/// The stored-vs-display unit convention for goal amounts, in one place:
/// duration goals are edited in minutes (daily) or hours (weekly) and
/// stored in seconds; count goals use raw values everywhere. The settings
/// form's read and write sides — and the intention form's hours target —
/// convert through this so the inverse math can't drift apart.
enum GoalUnit {
    case daily(MeasurementType)
    case weekly(MeasurementType)

    /// Seconds per display unit (1 for counts).
    private var scale: Double {
        switch self {
        case .daily(.count), .weekly(.count):
            1
        case .daily:
            60
        case .weekly:
            3600
        }
    }

    /// The editor's starting value when no goal is stored yet.
    var defaultDisplayValue: Double {
        switch self {
        case .daily(.count): 10
        case .weekly(.count): 50
        case .daily: 30
        case .weekly: 5
        }
    }

    func display(fromStored stored: Double?) -> Double {
        guard let stored else { return defaultDisplayValue }
        return stored / scale
    }

    func stored(fromDisplay display: Double) -> Double {
        display * scale
    }
}
