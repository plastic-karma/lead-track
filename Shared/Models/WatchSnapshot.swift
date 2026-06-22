import Foundation

/// A lightweight, codable mirror of one metric for the watch app. The watch
/// never opens the SwiftData store; it renders these snapshots and sends
/// recording actions back to the phone.
struct WatchMetricSnapshot: Codable, Equatable, Identifiable {
    let id: UUID
    let name: String
    let measurementType: MeasurementType
    let unit: String?
    let icon: String?
    let colorName: String?
    var runningSince: Date?
    var todayTotal: Double
    /// Seconds a countdown timer runs for, or nil when the metric counts up.
    var countdownDuration: TimeInterval?
}

extension WatchMetricSnapshot {
    /// The range a running countdown animates across, or nil when the metric
    /// isn't running or counts up.
    var countdownInterval: ClosedRange<Date>? {
        guard let since = runningSince, let target = countdownDuration, target > 0 else { return nil }
        return since ... since.addingTimeInterval(target)
    }
}

/// Everything the watch needs to render its UI, pushed from the phone over
/// WatchConnectivity and cached on the watch for offline launches.
struct WatchSnapshot: Codable, Equatable {
    var metrics: [WatchMetricSnapshot]

    static let empty = WatchSnapshot(metrics: [])
}
