import Foundation
#if canImport(SwiftData)
import SwiftData

enum IntentionActionStoreError: Error {
    case invalidDrafts
}

extension ModelContext {
    /// The action set belonging to one intention, in stable calendar order.
    func intentionActions(for intentionID: UUID) throws -> [IntentionAction] {
        let descriptor = FetchDescriptor<IntentionAction>(
            predicate: #Predicate { $0.intentionID == intentionID }
        )
        return try fetch(descriptor).sorted(by: IntentionAction.calendarOrder)
    }

    /// Reconciles a locally edited draft with the persisted set. Stable IDs
    /// keep existing rows (and their ICS UIDs) intact across edits.
    func replaceIntentionActions(
        for intentionID: UUID,
        with drafts: [IntentionActionDraft]
    ) throws {
        guard let drafts = IntentionActionDraft.validated(drafts) else {
            throw IntentionActionStoreError.invalidDrafts
        }
        let existing = try intentionActions(for: intentionID)
        let incomingIDs = Set(drafts.map(\.id))
        for action in existing where !incomingIDs.contains(action.stableID) {
            delete(action)
        }
        var existingByID: [UUID: IntentionAction] = [:]
        for action in existing {
            existingByID[action.stableID] = action
        }
        for draft in drafts {
            if let action = existingByID[draft.id] {
                action.apply(draft)
            } else {
                insert(IntentionAction(intentionID: intentionID, draft: draft))
            }
        }
    }

    /// Deletes an intention's standalone V3 action rows before deleting the
    /// intention itself. SwiftData cannot cascade across the scalar UUID link.
    func deleteIntentionAndActions(_ intention: Intention) throws {
        if let intentionID = intention.stableID {
            for action in try intentionActions(for: intentionID) {
                delete(action)
            }
        }
        delete(intention)
    }
}
#endif
