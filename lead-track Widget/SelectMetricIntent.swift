import AppIntents
import Foundation
import SwiftData

/// A duration metric the user can pick when configuring the Timer Control
/// widget, so each placed widget drives a single metric's timer.
struct MetricEntity: AppEntity {
    let id: String
    let name: String
    let icon: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Metric"
    static var defaultQuery = MetricQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(name)",
            image: .init(systemName: icon)
        )
    }
}

/// Lists selectable metrics from the shared store for the widget's metric
/// picker, limited to duration metrics since the Timer Control widget only
/// starts and stops timers.
struct MetricQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [MetricEntity] {
        let wanted = Set(identifiers)
        return try durationMetrics().filter { wanted.contains($0.id) }
    }

    func suggestedEntities() async throws -> [MetricEntity] {
        try durationMetrics()
    }
}

extension MetricQuery {
    private func durationMetrics() throws -> [MetricEntity] {
        let container = try SharedModelContainer.create()
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<Metric>(
            sortBy: [SortDescriptor(\.createdAt)]
        )
        // Health-linked metrics mirror Apple Health and have no timer to
        // drive, so they never appear in the picker; archived metrics rest
        // off the widget until they return.
        return try context.fetch(descriptor)
            .filter { $0.measurementType == .duration && !$0.isHealthLinked && !$0.isArchived }
            .compactMap { metric in
                guard let id = metric.stableID?.uuidString else {
                    return nil
                }
                return MetricEntity(
                    id: id,
                    name: metric.name,
                    icon: metric.displayIcon
                )
            }
    }
}

/// Widget configuration recording which metric a placed Timer Control widget
/// starts and stops.
struct SelectMetricIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Select Metric"

    @Parameter(title: "Metric") var metric: MetricEntity?

    init() {}
}
