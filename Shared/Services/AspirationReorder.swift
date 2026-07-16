import Foundation

/// The write path behind dragging a card into a new slot, shared by the
/// three tabs' card stacks. Pure list arithmetic over the full aspiration
/// set plus a rank rewrite the caller persists by saving its context;
/// unit-tested on Linux.
enum AspirationReorder {
    /// Applies one drag: the aspiration carrying `draggedID` reseats into
    /// the slot of the one carrying `targetID`, and every aspiration's
    /// `displayOrder` is rewritten to its resulting position. The first drag
    /// ever seeds the ranks from `visibleIDs` — the order the dragging
    /// screen was showing — so adopting manual order moves nothing on screen
    /// but the dragged card itself. Unknown IDs and self-drops change
    /// nothing (and never seed).
    static func applyMove(
        all: [Aspiration],
        visibleIDs: [String],
        draggedID: String,
        targetID: String
    ) {
        let base = all.hasManualOrder ? all.inDisplayOrder : seeded(all: all, visibleIDs: visibleIDs)
        guard let next = moved(base, draggedID: draggedID, targetID: targetID) else { return }
        for (rank, aspiration) in next.enumerated() where aspiration.displayOrder != rank {
            aspiration.displayOrder = rank
        }
    }

    /// The full canonical list rearranged so its on-screen members follow
    /// the screen's order while everything off-screen keeps its slot —
    /// Today may be showing its smart order, and a subset of aspirations at
    /// that, so seeding from the screen keeps the first drag visually quiet
    /// everywhere it can.
    static func seeded(all: [Aspiration], visibleIDs: [String]) -> [Aspiration] {
        let canonical = all.inDisplayOrder
        let byID = Dictionary(
            canonical.map { ($0.stableIdentity, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        var queue = visibleIDs.compactMap { byID[$0] }
        let visible = Set(queue.map(\.stableIdentity))
        return canonical.map { aspiration in
            guard visible.contains(aspiration.stableIdentity), !queue.isEmpty else { return aspiration }
            return queue.removeFirst()
        }
    }

    /// `base` with the dragged aspiration reseated in the target's slot —
    /// just below it when dragging down, just above when dragging up,
    /// matching how a hovered card visually yields. nil when the drag
    /// changes nothing.
    static func moved(
        _ base: [Aspiration],
        draggedID: String,
        targetID: String
    ) -> [Aspiration]? {
        guard let from = base.firstIndex(where: { $0.stableIdentity == draggedID }),
              let to = base.firstIndex(where: { $0.stableIdentity == targetID }),
              from != to
        else { return nil }
        var next = base
        let dragged = next.remove(at: from)
        next.insert(dragged, at: to)
        return next
    }
}
