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
        format(lifetime)
    }

    /// Recent (30-day) figure formatted the same way.
    var recentText: String {
        format(recent)
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

    private func format(_ value: Double) -> String {
        switch kind {
        case .duration:
            return DurationFormatter.format(value)
        case let .count(unit):
            return ValueFormatter.format(value, type: .count, unit: unit)
        case .entries:
            return Self.entriesText(Int(value))
        }
    }

    private static func entriesText(_ count: Int) -> String {
        count == 1 ? "1 entry" : "\(count) entries"
    }
}

extension RollupBucket.Kind {
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

/// The live, recomputed aggregate of an aspiration's effort across its current
/// attachments. Built fresh every time it is shown — never stored as a running
/// tally, so adding or removing an attachment immediately re-totals.
///
/// `SessionStatistics` stays the unit-blind per-bucket primitive; this layer
/// de-dups, partitions by unit, and aggregates across the attached items.
struct AspirationRollup {
    /// Aspiration-wide totals, one per distinct unit, merged across every
    /// contribution.
    let headline: [RollupBucket]
    /// Per-attachment breakdown, metrics first then standalone projects.
    let contributions: [Contribution]

    /// Default trailing window for the "recent" figure.
    static let recentWindowDays = 30

    /// Whether any attachment has logged effort (drives the zero state).
    var hasData: Bool {
        headline.contains { $0.lifetime > 0 }
    }

    /// How many metrics/projects feed this rollup after de-dup (drives the
    /// empty-attachment state).
    var attachmentCount: Int {
        contributions.count
    }

    /// Lifetime headline ("12h 40m · 340 pages · 18 entries").
    var lifetimeSummary: String {
        headline
            .filter { $0.lifetime > 0 }
            .map(\.lifetimeText)
            .joined(separator: " · ")
    }

    /// Recent headline parts; empty when nothing was logged in the window.
    var recentParts: [String] {
        headline
            .filter { $0.recent > 0 }
            .map(\.recentText)
    }
}

// MARK: - Single-attachment summary

extension AspirationRollup {
    /// One-line lifetime summary for a single attached metric ("8h 20m",
    /// "340 pages"), or `nil` when it has logged nothing yet. Lets the detail
    /// screen show per-attachment totals while iterating the models directly,
    /// reusing the same bucket logic as the headline.
    static func itemSummary(
        for metric: Metric,
        recentDays: Int = recentWindowDays
    ) -> String? {
        summary(of: contribution(of: metric, index: 0, days: recentDays))
    }

    /// One-line lifetime summary for a single attached project, or `nil` when
    /// it has logged nothing yet.
    static func itemSummary(
        for project: Project,
        recentDays: Int = recentWindowDays
    ) -> String? {
        summary(of: contribution(of: project, index: 0, days: recentDays))
    }

    private static func summary(of contribution: Contribution) -> String? {
        guard let bucket = contribution.buckets.first, bucket.lifetime > 0
        else { return nil }
        return bucket.lifetimeText
    }
}

// MARK: - Computation

extension AspirationRollup {
    static func compute(
        for aspiration: Aspiration,
        recentDays: Int = recentWindowDays
    ) -> AspirationRollup {
        let metrics = aspiration.metrics.sorted { $0.createdAt < $1.createdAt }
        let projects = standaloneProjects(of: aspiration, attachedMetrics: metrics)
        var contributions: [Contribution] = []
        for (index, metric) in metrics.enumerated() {
            contributions.append(contribution(of: metric, index: index, days: recentDays))
        }
        for (offset, project) in projects.enumerated() {
            contributions.append(
                contribution(of: project, index: metrics.count + offset, days: recentDays)
            )
        }
        return AspirationRollup(
            headline: mergeHeadline(from: contributions),
            contributions: contributions
        )
    }

    /// Projects whose effort isn't already pulled in by an attached metric. A
    /// project sharing an aspiration with its own parent metric is dropped — the
    /// metric already contains its sessions, so counting both double-counts.
    private static func standaloneProjects(
        of aspiration: Aspiration,
        attachedMetrics: [Metric]
    ) -> [Project] {
        let attached = Set(attachedMetrics.map(ObjectIdentifier.init))
        return aspiration.projects
            .filter { project in
                guard let parent = project.metric else { return true }
                return !attached.contains(ObjectIdentifier(parent))
            }
            .sorted { $0.startedAt < $1.startedAt }
    }

    private static func contribution(
        of metric: Metric,
        index: Int,
        days: Int
    ) -> Contribution {
        let kind = bucketKind(type: metric.measurementType, unit: metric.unit)
        let bucket = bucket(sessions: metric.sessions, kind: kind, days: days)
        return Contribution(
            id: "metric-\(index)", name: metric.name, isProject: false, buckets: [bucket]
        )
    }

    private static func contribution(
        of project: Project,
        index: Int,
        days: Int
    ) -> Contribution {
        let kind = bucketKind(
            type: project.metric?.measurementType ?? .duration,
            unit: project.metric?.unit
        )
        let bucket = bucket(sessions: project.sessions, kind: kind, days: days)
        return Contribution(
            id: "project-\(index)", name: project.name, isProject: true, buckets: [bucket]
        )
    }

    private static func bucketKind(
        type: MeasurementType,
        unit: String?
    ) -> RollupBucket.Kind {
        switch type {
        case .duration:
            return .duration
        case .count:
            let trimmed = (unit ?? "").trimmingCharacters(in: .whitespaces)
            return trimmed.isEmpty ? .entries : .count(unit: trimmed)
        }
    }

    private static func bucket(
        sessions: [Session],
        kind: RollupBucket.Kind,
        days: Int
    ) -> RollupBucket {
        let totals = SessionStatistics.dailyTotals(from: sessions)
        if case .entries = kind {
            return RollupBucket(
                kind: kind,
                lifetime: Double(SessionStatistics.totalSessions(from: totals)),
                recent: Double(SessionStatistics.windowedSessionCount(days: days, from: totals))
            )
        }
        return RollupBucket(
            kind: kind,
            lifetime: SessionStatistics.overallTotal(from: totals),
            recent: SessionStatistics.windowedTotal(days: days, from: totals)
        )
    }

    /// Folds every contribution's buckets into the aspiration-wide headline,
    /// merging by unit and ordering time → counts → entries while preserving
    /// each count unit's first-seen order.
    private static func mergeHeadline(
        from contributions: [Contribution]
    ) -> [RollupBucket] {
        var order: [String] = []
        var merged: [String: RollupBucket] = [:]
        for bucket in contributions.flatMap(\.buckets) {
            let key = bucket.kind.mergeKey
            if let existing = merged[key] {
                merged[key] = existing.adding(bucket)
            } else {
                order.append(key)
                merged[key] = bucket
            }
        }
        let buckets = order.compactMap { merged[$0] }
        return buckets.filter { $0.kind.sortRank == 0 }
            + buckets.filter { $0.kind.sortRank == 1 }
            + buckets.filter { $0.kind.sortRank == 2 }
    }
}
