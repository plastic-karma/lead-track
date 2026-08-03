import SwiftData

extension ModelContext {
    /// The one iOS delete path for an intention: atomically remove the model
    /// and its scalar-linked actions, then cancel its private daily ask only
    /// after persistence succeeds.
    func deleteIntention(_ intention: Intention) {
        let stableID = intention.stableID
        do {
            try transaction {
                try deleteIntentionAndActions(intention)
            }
            if let stableID {
                NotificationService.cancelQuestion(stableID: stableID)
            }
        } catch {
            StoreLog.error("Intention delete failed: \(error)")
        }
    }
}
