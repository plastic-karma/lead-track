import Foundation

/// One unit's worth of an aspiration's effort, shown two ways: the cumulative
/// `lifetime` figure and the trailing-30-day `recent` figure. Buckets never mix
/// units — duration, each distinct count unit, and unitless "entries" are kept
/// apart (see `Kind`).
struct RollupBucket: Identifiable, Equatable {
    enum Kind: Equatable {
        /// All `.duration` effort, formatted as time.
        case duration
        /// One distinct `.count` unit, carrying its display spelling.
        case count(unit: String)
        /// Unitless count contributions, whose magnitude is the number of
        /// sessions rather than their summed value.
        case entries
    }

    let kind: Kind
    let lifetime: Double
    let recent: Double

    var id: String {
        kind.mergeKey
    }
}

extension RollupBucket {
    /// Lifetime figure formatted for display ("12h 40m", "340 pages",
    /// "18 entries").
    var lifetimeText: String {
        kind.format(lifetime)
    }

    /// Recent (30-day) figure formatted the same way.
    var recentText: String {
        kind.format(recent)
    }

    /// Merges another bucket of the same `kind` into this one, summing both
    /// figures and keeping this bucket's display spelling.
    func adding(_ other: RollupBucket) -> RollupBucket {
        RollupBucket(
            kind: kind,
            lifetime: lifetime + other.lifetime,
            recent: recent + other.recent
        )
    }
}

extension RollupBucket.Kind {
    /// Formats a magnitude in this unit ("12h 40m", "340 pages", "18 entries").
    /// Shared by the lifetime rollup and the weekly review's windowed totals.
    func format(_ value: Double) -> String {
        switch self {
        case .duration: DurationFormatter.format(value)
        case let .count(unit): ValueFormatter.format(value, type: .count, unit: unit)
        case .entries: Self.entriesText(Int(value))
        }
    }

    private static func entriesText(_ count: Int) -> String {
        count == 1 ? "1 entry" : "\(count) entries"
    }

    /// Headline ordering: time first, then count units, then unitless entries.
    var sortRank: Int {
        switch self {
        case .duration: 0
        case .count: 1
        case .entries: 2
        }
    }

    /// The case-folded, trimmed key buckets merge on, so "Pages" and "pages "
    /// collapse into one headline figure. The first spelling encountered is the
    /// one displayed.
    var mergeKey: String {
        switch self {
        case .duration: "duration"
        case let .count(unit): "count:" + unit.lowercased()
        case .entries: "entries"
        }
    }
}

/// One attachment's share of the rollup — a metric (all its sessions, including
/// its projects') or a standalone project (only its own).
struct Contribution: Identifiable {
    let id: String
    let name: String
    let isProject: Bool
    let buckets: [RollupBucket]
}

/// One unit's total over a single window, formatted for display. A mixed-unit
/// headline like "2h 10m · 45 pages" is a list of these — used by the weekly
/// review, where a bucket carries one window's magnitude rather than the
/// rollup's lifetime/recent pair.
struct UnitTotal: Identifiable, Equatable {
    let kind: RollupBucket.Kind
    let value: Double

    var id: String {
        kind.mergeKey
    }

    var text: String {
        kind.format(value)
    }
}
