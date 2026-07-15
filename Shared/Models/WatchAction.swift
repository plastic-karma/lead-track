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

    /// Identifies one tap across delivery retries. WatchConnectivity is
    /// at-least-once — a reply timeout re-queues the identical payload even
    /// though the phone already applied it — so the phone drops actions
    /// whose ID it has seen. nil when decoded from an app version that
    /// predates the field; those apply without dedup, the old behavior.
    let id: UUID?
    let kind: Kind
    let metricID: UUID
    let value: Double?
    let timestamp: Date

    init(
        kind: Kind,
        metricID: UUID,
        value: Double? = nil,
        timestamp: Date = .now,
        id: UUID = UUID()
    ) {
        self.id = id
        self.kind = kind
        self.metricID = metricID
        self.value = value
        self.timestamp = timestamp
    }
}
