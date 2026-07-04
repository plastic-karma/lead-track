import Foundation
#if canImport(SwiftData)
import SwiftData
#endif

// A kept piece of testimony that an aspiration is being lived — the lag side of
// the app's lead measures. Every number elsewhere records what was *poured in*;
// a moment records something that *grew out*, in the user's own words. It is
// witnessed, never measured: written only by the user, never aggregated, scored,
// counted, or prompted (see `docs/MOMENTS.md`).
//
// Attached to exactly one owning aspiration, fixed at creation — the
// `Intention`/`AspirationCheckIn` shape — and optionally pointing at the metric
// or project where it happened (provenance, not membership). Mirrors the
// `#if canImport(SwiftData)` shape of `Intention` so the type also compiles in
// the Linux SwiftPM overlay, where it degrades to a plain class.
#if canImport(SwiftData)
@Model
#endif
final class Moment {
    #if canImport(SwiftData)
    #Unique<Moment>([\.stableID])
    #endif
    /// Stable identity, mirroring `Intention.stableID`.
    var stableID: UUID?
    /// The testimony, in the user's words — the only required field.
    var text: String
    /// When it happened. User-set and backdatable (moments are often kept days
    /// late), capped at now, and what every surface windows and sorts on —
    /// distinct from `createdAt`.
    var occurredAt: Date
    /// When it was kept; immutable.
    var createdAt: Date
    /// Plain doubles, not CoreLocation types, so the model compiles on Linux
    /// and the watch. Captured only on an explicit per-moment tap; nil when the
    /// user never asked.
    var latitude: Double?
    var longitude: Double?
    /// A short human label ("Golden Gate Bridge, San Francisco"),
    /// reverse-geocoded **once at capture**. Display renders this string and
    /// never geocodes again. Empty when no location was kept, or when the
    /// geocode failed and only coordinates remain.
    var placeName: String = ""

    /// The owning why — exactly one, fixed at creation. The cascade
    /// relationship is declared on `Aspiration.moments` (the
    /// `Intention`/`AspirationCheckIn` precedent): testimony is meaningless
    /// without its why, so deleting the aspiration takes its moments with it.
    var aspiration: Aspiration?

    // Provenance — *where it happened*, not membership. Nullify both ways,
    // mirroring `Intention.metric`: deleting the metric or project drops the
    // link and the moment's text stands alone; deleting the moment never
    // touches them. The linked metric/project need not be attached to the
    // owning aspiration.
    #if canImport(SwiftData)
    @Relationship(deleteRule: .nullify, inverse: \Metric.moments)
    #endif
    var metric: Metric?

    #if canImport(SwiftData)
    @Relationship(deleteRule: .nullify, inverse: \Project.moments)
    #endif
    var project: Project?

    // The moment's photos, ordered by `sortIndex`. Cascade — a photo dies with
    // its moment. A child model rather than a `[Data]` attribute so each photo
    // is its own lazily-loaded external blob: moments accrue for a lifetime,
    // and a text-only render must never drag photo bytes in.
    #if canImport(SwiftData)
    @Relationship(deleteRule: .cascade, inverse: \MomentPhoto.moment)
    #endif
    var photos: [MomentPhoto] = []

    init(
        text: String,
        aspiration: Aspiration?,
        occurredAt: Date = .now,
        metric: Metric? = nil,
        project: Project? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        placeName: String = "",
        createdAt: Date = .now
    ) {
        stableID = UUID()
        self.text = text
        self.aspiration = aspiration
        self.occurredAt = occurredAt
        self.metric = metric
        self.project = project
        self.latitude = latitude
        self.longitude = longitude
        self.placeName = placeName
        self.createdAt = createdAt
    }
}

// MARK: - Location

extension Moment {
    /// Whether a place was kept with this moment — coordinates present, whatever
    /// the geocode yielded for the name.
    var hasLocation: Bool {
        latitude != nil && longitude != nil
    }

    /// The chip's label: the reverse-geocoded name when one was found, a
    /// generic fallback when only coordinates remain, nil when no place was
    /// kept. Never geocodes — it reads the string stored at capture.
    var placeLabel: String? {
        guard hasLocation else { return nil }
        let trimmed = placeName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Location" : trimmed
    }
}

// A single photo kept with a moment. Its bytes live in on-device external
// storage so a text-only render never loads them. Ordered within its moment by
// `sortIndex`. The cascade + inverse live on `Moment.photos`; the back-pointer
// here is plain, the `Project.metric`/`Session.metric` precedent.
#if canImport(SwiftData)
@Model
#endif
final class MomentPhoto {
    #if canImport(SwiftData)
    @Attribute(.externalStorage)
    #endif
    var data: Data
    /// Position within the moment's strip, ascending.
    var sortIndex: Int
    var moment: Moment?

    init(data: Data, sortIndex: Int = 0, moment: Moment? = nil) {
        self.data = data
        self.sortIndex = sortIndex
        self.moment = moment
    }
}
