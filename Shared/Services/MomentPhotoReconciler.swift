#if canImport(SwiftData)
import Foundation
import SwiftData

/// Reconciles ordered photo bytes with a Moment without rewriting unchanged
/// external blobs. Shared by the composer and persistence tests.
enum MomentPhotoReconciler {
    static func sync(
        _ data: [Data],
        with moment: Moment,
        in context: ModelContext
    ) {
        let existing = moment.photos.sorted { $0.sortIndex < $1.sortIndex }
        guard existing.map(\.data) != data else { return }

        for photo in existing {
            context.delete(photo)
        }
        var replacements: [MomentPhoto] = []
        for (index, photoData) in data.enumerated() {
            let photo = MomentPhoto(
                data: photoData, sortIndex: index, moment: moment
            )
            context.insert(photo)
            replacements.append(photo)
        }
        moment.photos = replacements
    }
}

extension ModelContext {
    /// Enforces the declared Moment-photo cascade explicitly. SwiftData can
    /// leave the inverse array empty after loading an existing store, so
    /// deleting through the forward photo.moment link keeps blobs from
    /// becoming orphaned on every supported platform.
    func deleteMomentAndPhotos(_ moment: Moment) throws {
        let photos = try fetch(FetchDescriptor<MomentPhoto>())
        for photo in photos where photo.moment === moment {
            delete(photo)
        }
        delete(moment)
    }
}
#endif
