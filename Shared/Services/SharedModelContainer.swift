import Foundation
import SwiftData

enum SharedModelContainer {
    private static let groupID = "group.plastickarma.lead-track"
    private static let storeName = "lead-track.store"

    static func create(inMemoryOnly: Bool = false) throws -> ModelContainer {
        let schema = Schema([
            Metric.self,
            Project.self,
            Session.self
        ])
        let config: ModelConfiguration
        if inMemoryOnly {
            config = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: true,
                allowsSave: true
            )
        } else {
            config = ModelConfiguration(
                schema: schema,
                url: storeURL,
                allowsSave: true
            )
        }
        let container = try ModelContainer(
            for: schema, configurations: [config]
        )
        if !inMemoryOnly {
            try backfillMetricStableIDs(in: container)
        }
        return container
    }

    private static func backfillMetricStableIDs(
        in container: ModelContainer
    ) throws {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<Metric>(
            predicate: #Predicate { $0.stableID == nil }
        )
        let metrics = try context.fetch(descriptor)
        guard !metrics.isEmpty else { return }
        for metric in metrics {
            metric.stableID = UUID()
        }
        try context.save()
    }

    private static var storeURL: URL {
        let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: groupID
        )
        let base = groupURL ?? URL.documentsDirectory
        return base.appending(path: storeName)
    }
}
