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
#endif
