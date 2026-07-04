import Foundation
import SwiftData

enum SharedModelContainer {
    private static let storeName = "lead-track.store"

    static func create(inMemoryOnly: Bool = false) throws -> ModelContainer {
        let schema = Schema([
            Metric.self,
            Project.self,
            Session.self,
            Aspiration.self,
            Intention.self,
            AspirationCheckIn.self,
            Moment.self,
            MomentPhoto.self
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
            try backfillStableIDs(in: container)
        }
        return container
    }

    /// Mints stable IDs for any metric or aspiration saved before the field
    /// existed, so identity-keyed surfaces never see a nil ID.
    private static func backfillStableIDs(
        in container: ModelContainer
    ) throws {
        let context = ModelContext(container)
        let metrics = try context.fetch(
            FetchDescriptor<Metric>(predicate: #Predicate { $0.stableID == nil })
        )
        for metric in metrics where metric.stableID == nil {
            metric.stableID = UUID()
        }
        let aspirations = try context.fetch(
            FetchDescriptor<Aspiration>(predicate: #Predicate { $0.stableID == nil })
        )
        for aspiration in aspirations where aspiration.stableID == nil {
            aspiration.stableID = UUID()
        }
        if !metrics.isEmpty || !aspirations.isEmpty {
            try context.save()
        }
    }

    private static var storeURL: URL {
        let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: AppGroup.id
        )
        let base = groupURL ?? URL.documentsDirectory
        return base.appending(path: storeName)
    }
}
