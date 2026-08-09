import AppIntents
import Foundation
import SwiftData

/// A favorite metric the user can choose while placing LeadStone's Metric
/// Action control. It carries display data only; execution always re-fetches
/// the metric by stable ID from the shared store.
struct FavoriteMetricEntity: AppEntity {
    let id: String
    let name: String
    let icon: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Favorite Metric"
    static var defaultQuery = FavoriteMetricQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(name)",
            image: .init(systemName: icon)
        )
    }
}

/// Favorites curate the configuration picker without owning controls that
/// are already placed. Identifier resolution therefore keeps an unfavorited
/// metric working, while suggestions contain only current favorites.
struct FavoriteMetricQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [FavoriteMetricEntity] {
        let wanted = Set(identifiers)
        return try metricEntities(onlyFavorites: false)
            .filter { wanted.contains($0.id) }
    }

    func suggestedEntities() async throws -> [FavoriteMetricEntity] {
        try metricEntities(onlyFavorites: true)
    }
}

extension FavoriteMetricQuery {
    private func metricEntities(onlyFavorites: Bool) throws -> [FavoriteMetricEntity] {
        guard let container = SharedModelContainer.shared else { return [] }
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<Metric>(
            sortBy: [SortDescriptor(\.createdAt)]
        )
        return try context.fetch(descriptor)
            .filter { metric in
                !onlyFavorites || (metric.isFavorite && metric.isControlEligible)
            }
            .compactMap { Self.entity(for: $0) }
    }

    private static func entity(for metric: Metric) -> FavoriteMetricEntity? {
        guard let id = metric.stableID?.uuidString else { return nil }
        return FavoriteMetricEntity(
            id: id,
            name: metric.name,
            icon: metric.displayIcon
        )
    }
}

/// Records which favorite a placed Control Center control acts on.
struct SelectFavoriteMetricIntent: ControlConfigurationIntent {
    static var title: LocalizedStringResource = "Select Favorite Metric"
    static var isDiscoverable = false

    @Parameter(title: "Metric") var metric: FavoriteMetricEntity?

    init() {}
}
