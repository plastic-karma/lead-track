import Foundation

enum MeasurementType: String, Codable, CaseIterable {
    case duration
    case count
    /// A once-a-day done/not-done habit (e.g. "read scripture"): at most one
    /// completed session per day, value `1`, and quantity is irrelevant.
    case binary
}

extension MeasurementType {
    /// Whether recordings accumulate a magnitude. Duration and count do; binary
    /// only ever marks a day done, so quantity-shaped affordances — units,
    /// custom amounts, timers, and amount goals — apply only when this is true.
    var tracksQuantity: Bool {
        self != .binary
    }
}
