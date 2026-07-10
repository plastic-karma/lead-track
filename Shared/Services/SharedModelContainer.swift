import Foundation
import SwiftData
#if canImport(os)
import os
#endif

/// The store's schema history. Every released shape gets a version here so
/// future non-additive changes (renames, tightened optionality, new #Unique
/// constraints) have a custom-migration hook and fixture stores to test
/// against — instead of relying on implicit lightweight migration and
/// discovering the first hard break as a launch crash on real data.
enum LeadTrackSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

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
            MomentPhoto.self
        ]
    }
}

enum LeadTrackMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [LeadTrackSchemaV1.self]
    }

    /// Purely additive evolution so far; the first breaking change appends a
    /// stage (usually `.lightweight`) between its old and new schema.
    static var stages: [MigrationStage] {
        []
    }
}

enum SharedModelContainer {
    private static let storeName = "lead-track.store"

    /// One container per process. Widget timeline reloads and intent
    /// invocations share it instead of rebuilding the whole stack — and
    /// re-running the stable-ID backfill — on every call. nil when the
    /// store failed to open; consumers render a distinct failure state
    /// rather than impersonating "no data yet".
    static let shared: ModelContainer? = {
        do {
            return try create()
        } catch {
            StoreLog.error("Shared store failed to open: \(error)")
            return nil
        }
    }()

    static func create(inMemoryOnly: Bool = false) throws -> ModelContainer {
        let schema = Schema(versionedSchema: LeadTrackSchemaV1.self)
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
