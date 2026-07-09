import Foundation
#if canImport(SwiftData)
import SwiftData
#endif

// A short vow held under one aspiration — "Pages before feeds." — the why
// distilled into a sentence that can be lived. It carries no target, no
// deadline, and no machinery of its own: intentions name the principle they
// serve, moments name the principle they live, and the principle's only
// record is which weeks that service actually happened (see
// `PrincipleLiving`). Mirrors the `#if canImport(SwiftData)` shape of
// `Intention` so the type also compiles in the Linux SwiftPM overlay, where
// it degrades to a plain class.
#if canImport(SwiftData)
@Model
#endif
final class Principle {
    #if canImport(SwiftData)
    #Unique<Principle>([\.stableID])
    #endif
    /// Stable identity, mirroring `Intention.stableID`.
    var stableID: UUID?
    /// The vow, in the user's words.
    var text: String
    /// When it was first held; the creed's reading order.
    var createdAt: Date

    /// The owning why — exactly one, the `Intention`/`Moment` shape. The
    /// cascade relationship is declared on `Aspiration.principles`: a vow is
    /// meaningless without its why.
    var aspiration: Aspiration?

    // Back-arrays for the intentions serving and the moments living this
    // principle — always drawn from the owning aspiration's own (every writer
    // offers only those). Plain (no macro): the `@Relationship` lives on
    // `Intention.principle` / `Moment.principle`, the `Metric.intentions`
    // precedent. Nullify both ways — deleting a principle leaves them
    // standing untagged, and deleting them never touches the principle.
    var intentions: [Intention] = []
    var moments: [Moment] = []

    init(text: String, aspiration: Aspiration?, createdAt: Date = .now) {
        stableID = UUID()
        self.text = text
        self.aspiration = aspiration
        self.createdAt = createdAt
    }
}
