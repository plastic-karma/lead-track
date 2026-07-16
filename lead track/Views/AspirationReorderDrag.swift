import SwiftUI
import UniformTypeIdentifiers

/// Long-press drag-to-reorder for the aspiration-anchored card stacks — the
/// Today clusters, the Week tab's metric groups, and the Aspirations list.
/// Each stack marks its cards `aspirationReorderable`; hovering another card
/// reseats the dragged aspiration's rank right away (see
/// `AspirationReorder.applyMove`), so the stack reflows live under the drag
/// and the arrangement is already persisted however the session ends.
extension View {
    /// Marks one card as a drag source and drop slot in its stack. `id` is
    /// the aspiration's stable identity; nil leaves the card out of the
    /// dance entirely (the unaligned pseudo-cluster, which always trails).
    @ViewBuilder
    func aspirationReorderable(
        id: String?,
        draggingID: Binding<String?>,
        move: @escaping (_ draggedID: String, _ targetID: String) -> Void
    ) -> some View {
        if let id {
            opacity(draggingID.wrappedValue == id ? 0.4 : 1)
                .onDrag {
                    draggingID.wrappedValue = id
                    let provider = ReorderDragSessionProvider(object: id as NSString)
                    provider.dragEnded = {
                        DispatchQueue.main.async {
                            if draggingID.wrappedValue == id {
                                draggingID.wrappedValue = nil
                            }
                        }
                    }
                    return provider
                }
                .onDrop(
                    of: [.text],
                    delegate: AspirationReorderDropDelegate(
                        targetID: id, draggingID: draggingID, move: move
                    )
                )
        } else {
            self
        }
    }

    /// Lets the stack's whole scroll surface finish a drag released between
    /// or beyond the cards: the reorder already landed hover by hover, so
    /// the catch-all only clears the dimmed drag source.
    func aspirationReorderDropSurface(draggingID: Binding<String?>) -> some View {
        onDrop(of: [.text], delegate: AspirationReorderEndDelegate(draggingID: draggingID))
    }
}

/// The dragged card's payload, doubling as the end-of-session sensor. The
/// system holds the provider for exactly the drag session's lifetime, so its
/// release is the one signal that fires however the session ends — dropped
/// on a card, released between cards, or cancelled. The delegate-side clears
/// below still run when they fire (they're immediate), but they can't be
/// relied on alone: after the stack reflows under a stationary finger,
/// SwiftUI often ends the session without calling `performDrop` at all,
/// which would leave the source card dimmed until the next drag.
private final class ReorderDragSessionProvider: NSItemProvider {
    var dragEnded: (() -> Void)?

    deinit {
        dragEnded?()
    }
}

/// Reseats the dragged card the moment it hovers a sibling, List-style, so
/// the stack reflows under the finger instead of waiting for the release.
private struct AspirationReorderDropDelegate: DropDelegate {
    let targetID: String
    @Binding var draggingID: String?
    let move: (_ draggedID: String, _ targetID: String) -> Void

    /// Only an in-app card drag may land; foreign payloads (a text drag
    /// from another app) fall through untouched.
    func validateDrop(info: DropInfo) -> Bool {
        draggingID != nil
    }

    func dropEntered(info: DropInfo) {
        guard let draggedID = draggingID, draggedID != targetID else { return }
        move(draggedID, targetID)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingID = nil
        return true
    }
}

/// The scroll surface's catch-all (see `aspirationReorderDropSurface`).
private struct AspirationReorderEndDelegate: DropDelegate {
    @Binding var draggingID: String?

    func validateDrop(info: DropInfo) -> Bool {
        draggingID != nil
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        guard draggingID != nil else { return false }
        draggingID = nil
        return true
    }
}
