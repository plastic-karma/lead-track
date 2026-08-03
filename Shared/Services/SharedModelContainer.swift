import Foundation
import SwiftData
#if canImport(os)
import os
#endif

/// V1 and V2 are frozen alongside their historical model declarations. V3 is
/// the app's current schema and adds scheduled intention actions as a
/// standalone entity, leaving every previously shipped entity unchanged.
enum LeadTrackSchemaV3: VersionedSchema {
    static let versionIdentifier = Schema.Version(3, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            Metric.self,
            Project.self,
            Session.self,
            Aspiration.self,
            Principle.self,
            Intention.self,
            AspirationCheckIn.self,
            Moment.self,
            MomentPhoto.self,
            IntentionAction.self
        ]
    }
}

enum LeadTrackMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [
            LeadTrackHistoricalSchemaV1.self,
            LeadTrackHistoricalSchemaV2.self,
            LeadTrackSchemaV3.self
        ]
    }

    static var stages: [MigrationStage] {
        [
            .lightweight(
                fromVersion: LeadTrackHistoricalSchemaV1.self,
                toVersion: LeadTrackHistoricalSchemaV2.self
            ),
            .lightweight(
                fromVersion: LeadTrackHistoricalSchemaV2.self,
                toVersion: LeadTrackSchemaV3.self
            )
        ]
    }
}

enum SharedModelContainer {
    private static let storeName = "lead-track.store"
    private static let schemaGeneration = "3.0.0"

    /// One container per process. Widget timeline reloads and intent
    /// invocations share it instead of rebuilding the whole stack — and
    /// re-running the stable-ID backfill — on every call. nil when the
    /// store failed to open; consumers render a distinct failure state
    /// rather than impersonating "no data yet".
    static var shared: ModelContainer? {
        sharedCache.value {
            guard isSchemaReady else {
                StoreLog.error("Shared store is waiting for the app to finish migration")
                return nil
            }
            do {
                return try create()
            } catch {
                StoreLog.error("Shared store failed to open: \(error)")
                return nil
            }
        }
    }

    private static let sharedCache = SharedContainerCache()

    static func create(inMemoryOnly: Bool = false) throws -> ModelContainer {
        let schema = Schema(versionedSchema: LeadTrackSchemaV3.self)
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
            for: schema,
            migrationPlan: LeadTrackMigrationPlan.self,
            configurations: [config]
        )
        if !inMemoryOnly {
            try backfillStableIDs(in: container)
            try markSchemaReady()
        }
        return container
    }

    /// Mints stable IDs for any metric, aspiration, or intention saved before
    /// the field existed, so identity-keyed surfaces never see a nil ID.
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
        let intentions = try context.fetch(
            FetchDescriptor<Intention>(predicate: #Predicate { $0.stableID == nil })
        )
        for intention in intentions where intention.stableID == nil {
            intention.stableID = UUID()
        }
        if !metrics.isEmpty || !aspirations.isEmpty || !intentions.isEmpty {
            try context.save()
        }
    }

    private static var storeURL: URL {
        let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: AppGroup.id
        )
        guard let groupURL else {
            // A nil group URL means a broken app-group entitlement, and the
            // per-sandbox fallback silently splits the store: the app, the
            // widgets, and the intents would each open a different, mostly
            // empty database. Fail loudly in development.
            assertionFailure("App-group container unavailable; falling back to a per-sandbox store")
            StoreLog.error("App-group container unavailable; using documentsDirectory")
            return URL.documentsDirectory.appending(path: storeName)
        }
        return groupURL.appending(path: storeName)
    }

    /// Extensions never become the first process to migrate the app-group
    /// store. The containing app writes this tiny file atomically only after
    /// opening, migrating, backfilling, and saving the current schema.
    private static var isSchemaReady: Bool {
        (try? String(contentsOf: schemaMarkerURL, encoding: .utf8))
            == schemaGeneration
    }

    private static func markSchemaReady() throws {
        try schemaGeneration.write(
            to: schemaMarkerURL,
            atomically: true,
            encoding: .utf8
        )
    }

    private static var schemaMarkerURL: URL {
        storeURL.deletingLastPathComponent()
            .appending(path: "lead-track-schema-ready")
    }
}

/// Caches only a successful extension-side open. A process that checked
/// before the app finished migration may retry later instead of retaining nil
/// for its whole lifetime.
private final class SharedContainerCache: @unchecked Sendable {
    private let lock = NSLock()
    private var container: ModelContainer?

    func value(create: () -> ModelContainer?) -> ModelContainer? {
        lock.lock()
        defer { lock.unlock() }
        if let container { return container }
        let created = create()
        container = created
        return created
    }
}

/// Store-lifecycle logging, mirroring the SyncLog pattern: identifiers and
/// error descriptions only, never user content.
enum StoreLog {
    #if canImport(os)
    private static let logger = Logger(
        subsystem: "plastickarma.lead-track",
        category: "store"
    )
    #endif

    static func error(_ message: String) {
        #if canImport(os)
        logger.error("\(message, privacy: .public)")
        #endif
    }
}
