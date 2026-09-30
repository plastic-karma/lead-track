import Foundation

/// Imported content that starts a new composer. It carries no PhotoKit or
/// extension identifiers — only the same stripped JPEG bytes the ordinary
/// picker produces — so every capture route converges before persistence.
struct MomentFormSeed {
    let photos: [Data]
    let occurredAt: Date
    let importFailureCount: Int

    init(
        photos: [Data] = [],
        occurredAt: Date = .now,
        importFailureCount: Int = 0
    ) {
        self.photos = photos
        self.occurredAt = occurredAt
        self.importFailureCount = max(0, importFailureCount)
    }
}
