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
    var runningSince: Date?
    var todayTotal: Double
}

/// Everything the watch needs to render its UI, pushed from the phone over
/// WatchConnectivity and cached on the watch for offline launches.
struct WatchSnapshot: Codable, Equatable {
    var metrics: [WatchMetricSnapshot]

    static let empty = WatchSnapshot(metrics: [])
}
