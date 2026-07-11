import Foundation
#if canImport(SwiftData)
import SwiftData

extension ModelContext {
    /// Deletes an aspiration and the records that are meaningless without
    /// it — intentions, principles, check-ins, and moments (with their
    /// photos), exactly the model's declared cascades. The dependents are
    /// resolved by reading the forward side (`intention.aspiration` etc.):
    /// this store's inverse back-arrays are not reliably populated, and the
    /// first real-SwiftData run of the overlay suite showed the declared
    /// cascade deleting nothing through an empty inverse. Explicit deletion
    /// keeps the rule true regardless.
    func deleteAspirationAndDependents(_ aspiration: Aspiration) throws {
        try deleteDependents(of: aspiration, as: Intention.self, by: \.aspiration)
        try deleteDependents(of: aspiration, as: Principle.self, by: \.aspiration)
        try deleteDependents(of: aspiration, as: AspirationCheckIn.self, by: \.aspiration)
        try deleteMoments(of: aspiration)
        delete(aspiration)
    }

    private func deleteDependents<Dependent: PersistentModel>(
        of aspiration: Aspiration,
        as type: Dependent.Type,
        by owner: KeyPath<Dependent, Aspiration?>
    ) throws {
        let all = try fetch(FetchDescriptor<Dependent>())
        for dependent in all where dependent[keyPath: owner] === aspiration {
            delete(dependent)
        }
    }

    private func deleteMoments(of aspiration: Aspiration) throws {
        let photos = try fetch(FetchDescriptor<MomentPhoto>())
        let moments = try fetch(FetchDescriptor<Moment>())
        for moment in moments where moment.aspiration === aspiration {
            for photo in photos where photo.moment === moment {
                delete(photo)
            }
            delete(moment)
        }
    }
}
#endif
