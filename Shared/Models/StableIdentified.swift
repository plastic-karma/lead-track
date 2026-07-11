import Foundation

/// One identity convention for every surface that keys UI on a model: the
/// stable UUID once the backfill has minted it, else the human-side text —
/// a pre-backfill fallback that only exists for rows saved before stable
/// IDs did (and can collide, which is why the backfill runs at container
/// creation).
protocol StableIdentified {
    var stableID: UUID? { get }
    /// The pre-backfill fallback identity.
    var identityFallback: String { get }
}

extension StableIdentified {
    var stableIdentity: String {
        stableID?.uuidString ?? identityFallback
    }
}

extension Metric: StableIdentified {
    var identityFallback: String {
        name
    }
}

extension Aspiration: StableIdentified {
    var identityFallback: String {
        title
    }
}

extension Intention: StableIdentified {
    var identityFallback: String {
        title
    }
}

extension Moment: StableIdentified {
    var identityFallback: String {
        text
    }
}

/// The sentinel grouping key for effort not aligned to any aspiration,
/// shared by the Today clusters and the Week tab's metric groups.
enum AspirationGrouping {
    static let unalignedID = "unaligned"
}
