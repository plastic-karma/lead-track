import Foundation
#if canImport(SwiftData)
import SwiftData

extension ModelContext {
    /// Deletes an aspiration and the records that are meaningless without
    /// it — intentions (with scheduled actions), principles, check-ins, and
    /// moments (with their photos), exactly the model's declared cascades.
    /// The dependents are resolved by reading the forward side
    /// (`intention.aspiration` etc.):
    /// this store's inverse back-arrays are not reliably populated, and the
    /// first real-SwiftData run of the overlay suite showed the declared
    /// cascade deleting nothing through an empty inverse. Explicit deletion
    /// keeps the rule true regardless.
    func deleteAspirationAndDependents(_ aspiration: Aspiration) throws {
        let intentions = try fetch(FetchDescriptor<Intention>())
        let moments = try fetch(FetchDescriptor<Moment>())
        let principles = try fetch(FetchDescriptor<Principle>())
        let checkIns = try fetch(FetchDescriptor<AspirationCheckIn>())
        let actions = try fetch(FetchDescriptor<IntentionAction>())
        let photos = try fetch(FetchDescriptor<MomentPhoto>())

        let ownedIntentions = intentions.filter { $0.aspiration === aspiration }
        let intentionIDs = Set(ownedIntentions.compactMap(\.stableID))
        let ownedMoments = moments.filter { $0.aspiration === aspiration }

        actions.filter { intentionIDs.contains($0.intentionID) }.forEach(delete)
        photos.filter { photo in
            ownedMoments.contains { $0 === photo.moment }
        }.forEach(delete)
        ownedIntentions.forEach(delete)
        principles.filter { $0.aspiration === aspiration }.forEach(delete)
        checkIns.filter { $0.aspiration === aspiration }.forEach(delete)
        ownedMoments.forEach(delete)
        delete(aspiration)
    }
}
#endif
