import Foundation
#if canImport(SwiftData)
import SwiftData
#endif

// An ongoing, never-"done" theme effort is poured into over a lifetime — a
// lens layered *above* the Metric → Project → Session hierarchy. It owns no
// sessions; it references metrics and projects (many-to-many) and aggregates
// their effort live (see `AspirationRollup`). Unlike a `Goal` it carries no
// target, deadline, pace, or streak.
//
// Mirrors the `#if canImport(SwiftData)` shape of `Metric`/`Project`/`Session`
// so the type also compiles in the Linux SwiftPM overlay, where it degrades to
// a plain class with a `Data?` and two arrays.
#if canImport(SwiftData)
@Model
#endif
final class Aspiration {
    var title: String
    var detail: String = ""
    var icon: String?
    var colorName: String?

    #if canImport(SwiftData)
    @Attribute(.externalStorage)
    #endif
    var imageData: Data?

    var createdAt: Date

    // Both attachments are many-to-many. The `inverse:` macro lives here and
    // here only — SwiftData requires it on exactly one side, and Aspiration is
    // the type introducing the relationship. `Metric`/`Project` carry plain
    // back-arrays. Nullify (never cascade): deleting an aspiration severs the
    // links and drops its image; the metrics, projects, and sessions survive.
    #if canImport(SwiftData)
    @Relationship(deleteRule: .nullify, inverse: \Metric.aspirations)
    #endif
    var metrics: [Metric] = []

    #if canImport(SwiftData)
    @Relationship(deleteRule: .nullify, inverse: \Project.aspirations)
    #endif
    var projects: [Project] = []

    init(
        title: String,
        detail: String = "",
        icon: String? = nil,
        colorName: String? = nil,
        imageData: Data? = nil,
        createdAt: Date = .now
    ) {
        self.title = title
        self.detail = detail
        self.icon = icon
        self.colorName = colorName
        self.imageData = imageData
        self.createdAt = createdAt
    }
}

// MARK: - Display

extension Aspiration {
    /// The SF Symbol every surface shows, with a shared fallback for
    /// aspirations saved without one.
    var displayIcon: String {
        icon ?? "mountain.2"
    }
}
