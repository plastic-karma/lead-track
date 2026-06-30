import Foundation

/// A recording command sent from the watch to the phone. The timestamp is
/// when the user tapped, so actions queued while the phone was unreachable
/// still record the right moment once delivered.
struct WatchAction: Codable, Equatable {
    enum Kind: String, Codable {
        case startTimer
        case stopTimer
        case logValue
        /// Marks the day done for a binary metric, or clears it if already
        /// done — the toggle behind the watch's check-off row.
        case toggleDay
    }

    let kind: Kind
    let metricID: UUID
    let value: Double?
    let timestamp: Date

    init(
        kind: Kind,
        metricID: UUID,
        value: Double? = nil,
        timestamp: Date = .now
    ) {
        self.kind = kind
        self.metricID = metricID
        self.value = value
        self.timestamp = timestamp
    }
}
