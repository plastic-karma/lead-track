import Foundation
import SwiftData

enum SharedModelContainer {
    private static let groupID = "group.plastickarma.lead-track"
    private static let storeName = "lead-track.store"

    static func create() throws -> ModelContainer {
        let schema = Schema([
            Metric.self,
            Project.self,
            Session.self
        ])
        let config = ModelConfiguration(
            schema: schema,
            url: storeURL,
            allowsSave: true
        )
        return try ModelContainer(for: schema, configurations: [config])
    }

    private static var storeURL: URL {
        let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: groupID
        )
        let base = groupURL ?? URL.documentsDirectory
        return base.appending(path: storeName)
    }
}
