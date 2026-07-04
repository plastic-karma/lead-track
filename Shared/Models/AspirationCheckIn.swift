import Foundation
#if canImport(SwiftData)
import SwiftData
#endif

// A weekly, always-skippable, per-aspiration alignment pulse — deliberately
// the app's only *subjective* time series. Every number in the app measures
// output; a check-in records the one thing output can't: whether the effort
// still serves the why. One row per aspiration per calendar week, enforced in
// logic (the composer edits the current week's row), never in schema.
//
// The check-in must never itself become a metric: no streaks, no completion
// rate, no notifications, no queued debt — absence is silence, the same
// doctrine as intention closures. Mirrors the `#if canImport(SwiftData)`
// shape of `Intention` so the type also compiles in the Linux SwiftPM
// overlay, where it degrades to a plain class.
#if canImport(SwiftData)
@Model
#endif
final class AspirationCheckIn {
    #if canImport(SwiftData)
    #Unique<AspirationCheckIn>([\.stableID])
    #endif
    /// Stable identity, mirroring `Intention.stableID`.
    var stableID: UUID?
    /// Normalized start of the check-in's **calendar week** — the same
    /// convention as `Intention.weekStart(containing:)`, which is what makes
    /// check-ins dedupable per week. (The Weekly Review period is a trailing
    /// seven-day window, not a calendar week.)
    var weekStart: Date
    /// 1–3 (see `AlignmentRating`), stored raw so a store written by a newer
    /// app version with an unknown scale still opens — the `kindRaw` pattern.
    var ratingRaw: Int
    /// Optional free text, in the user's words.
    var note: String = ""
    var createdAt: Date

    /// The owning aspiration. The cascade relationship is declared on
    /// `Aspiration.checkIns` — a check-in is meaningless without its why.
    var aspiration: Aspiration?

    init(
        aspiration: Aspiration?,
        rating: AlignmentRating,
        weekStart: Date,
        note: String = "",
        createdAt: Date = .now
    ) {
        stableID = UUID()
        self.aspiration = aspiration
        ratingRaw = rating.rawValue
        self.weekStart = weekStart
        self.note = note
        self.createdAt = createdAt
    }
}

// MARK: - Rating

/// The three-point alignment scale. Three points, not five: five stars read
/// as a grade of the user's week — performance, the exact framing to avoid —
/// and sparse subjective data can't honestly support five levels of trend
/// resolution anyway. The question above the control is always "Is this
/// effort still serving the why?", never "how did you do?".
enum AlignmentRating: Int, CaseIterable {
    case drifting = 1
    case unsure = 2
    case serving = 3
}

extension AlignmentRating {
    /// The composer's full answer wording.
    var label: String {
        switch self {
        case .drifting: "Feels off the why"
        case .unsure: "Somewhere between"
        case .serving: "Serving the why"
        }
    }

    /// Capsule-sized form of `label` for tight button rows.
    var shortLabel: String {
        switch self {
        case .drifting: "Feels off"
        case .unsure: "Unsure"
        case .serving: "Serving"
        }
    }
}

extension AspirationCheckIn {
    /// The stored rating, nil when the raw value is foreign to this version.
    var rating: AlignmentRating? {
        AlignmentRating(rawValue: ratingRaw)
    }
}
