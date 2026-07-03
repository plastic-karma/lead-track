import AppIntents
import Foundation

/// A metric the user can pick when configuring the Metric Progress
/// complication. Backed by the cached snapshot — the watch never opens the
/// SwiftData store.
struct WatchMetricEntity: AppEntity {
    let id: String
    let name: String
    let icon: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Metric"
    static var defaultQuery = WatchMetricQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(name)",
            image: .init(systemName: icon)
        )
    }
}

extension WatchMetricEntity {
    init(_ metric: WatchMetricSnapshot) {
        self.init(
            id: metric.id.uuidString,
            name: metric.name,
            icon: metric.icon ?? "clock"
        )
    }
}

/// Lists every cached metric for the complication's picker. Complications
/// are read-only, so health-linked metrics are eligible too.
struct WatchMetricQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [WatchMetricEntity] {
        let wanted = Set(identifiers)
        return allEntities().filter { wanted.contains($0.id) }
    }

    func suggestedEntities() async throws -> [WatchMetricEntity] {
        allEntities()
    }

    private func allEntities() -> [WatchMetricEntity] {
        WatchSnapshotCache.load().metrics.map(WatchMetricEntity.init)
    }
}

/// The Metric Progress complication's display styles.
enum MetricComplicationStyle: String, AppEnum {
    case number
    case numberRing
    case percent
    case percentRing

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Display Style"

    static var caseDisplayRepresentations: [MetricComplicationStyle: DisplayRepresentation] = [
        .number: "Value",
        .numberRing: "Value in Ring",
        .percent: "Percent",
        .percentRing: "Percent in Ring"
    ]

    /// Whether the style wraps its label in a progress ring.
    var showsRing: Bool {
        self == .numberRing || self == .percentRing
    }

    /// Whether the style prints goal percentage rather than the raw value.
    var showsPercent: Bool {
        self == .percent || self == .percentRing
    }
}

/// Configuration for one placed Metric Progress complication: which metric
/// to show and how to draw it.
struct SelectWatchMetricIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Select Metric"

    @Parameter(title: "Metric") var metric: WatchMetricEntity?
    @Parameter(title: "Style", default: .percentRing) var style: MetricComplicationStyle

    init() {}

    init(metric: WatchMetricEntity?, style: MetricComplicationStyle) {
        self.init()
        self.metric = metric
        self.style = style
    }
}
