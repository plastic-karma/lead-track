import Foundation

/// One attached metric or standalone project after de-dup: its display
/// identity, the unit bucket it falls in, and the sessions that count toward
/// it. The shared primitive behind both the lifetime rollup and the weekly
/// review's windowed totals, so the de-dup and unit rules live in one place.
struct ContributionSource {
    let name: String
    let isProject: Bool
    let kind: RollupBucket.Kind
    let sessions: [Session]
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
        summary(of: source(of: metric), days: recentDays)
    }

    /// One-line lifetime summary for a single attached project, or `nil` when
    /// it has logged nothing yet.
    static func itemSummary(
        for project: Project,
        recentDays: Int = recentWindowDays
    ) -> String? {
        summary(of: source(of: project), days: recentDays)
    }

    private static func summary(of source: ContributionSource, days: Int) -> String? {
        let bucket = bucket(over: source.sessions, kind: source.kind, days: days)
        guard bucket.lifetime > 0 else { return nil }
        return bucket.lifetimeText
    }
}

// MARK: - Computation

extension AspirationRollup {
    static func compute(
        for aspiration: Aspiration,
        recentDays: Int = recentWindowDays
    ) -> AspirationRollup {
        let contributions = contributionSources(of: aspiration)
            .enumerated()
            .map { index, source in
                Contribution(
                    id: "\(source.isProject ? "project" : "metric")-\(index)",
                    name: source.name,
                    isProject: source.isProject,
                    buckets: [bucket(over: source.sessions, kind: source.kind, days: recentDays)]
                )
            }
        return AspirationRollup(
            headline: merge(contributions.flatMap(\.buckets)),
            contributions: contributions
        )
    }

    /// The de-duped, unit-classified contributions of an aspiration: attached
    /// metrics first (each pulling in its own projects' sessions), then
    /// standalone projects. A project sharing an aspiration with its own parent
    /// metric is dropped — the metric already contains its sessions, so counting
    /// both would double-count.
    static func contributionSources(of aspiration: Aspiration) -> [ContributionSource] {
        let metrics = aspiration.metrics.sorted { $0.createdAt < $1.createdAt }
        let attached = Set(metrics.map(ObjectIdentifier.init))
        let projects = aspiration.projects
            .filter { project in
                guard let parent = project.metric else { return true }
                return !attached.contains(ObjectIdentifier(parent))
            }
            .sorted { $0.startedAt < $1.startedAt }
        return metrics.map(source(of:)) + projects.map(source(of:))
    }

    /// Magnitude of a unit bucket over `sessions`: summed tracking value, or the
    /// session count for the unitless `entries` bucket. Running sessions never
    /// count. The per-window primitive the weekly review totals with.
    static func magnitude(
        of kind: RollupBucket.Kind,
        over sessions: [Session]
    ) -> Double {
        let completed = sessions.filter { !$0.isRunning }
        if case .entries = kind {
            return Double(completed.count)
        }
        return completed.reduce(0) { $0 + $1.trackingValue }
    }

    /// Merges kinded items by their unit (case-folded, first spelling wins),
    /// preserving first-seen order, then orders time → counts → entries. Shared
    /// by the lifetime headline and the weekly review's windowed totals.
    static func mergeByUnit<T>(
        _ items: [T],
        kind: (T) -> RollupBucket.Kind,
        combine: (T, T) -> T
    ) -> [T] {
        var order: [String] = []
        var merged: [String: T] = [:]
        for item in items {
            let key = kind(item).mergeKey
            if let existing = merged[key] {
                merged[key] = combine(existing, item)
            } else {
                order.append(key)
                merged[key] = item
            }
        }
        let result = order.compactMap { merged[$0] }
        return (0 ... 2).flatMap { rank in result.filter { kind($0).sortRank == rank } }
    }
}

// MARK: - Bucketing Primitives

private extension AspirationRollup {
    static func source(of metric: Metric) -> ContributionSource {
        ContributionSource(
            name: metric.name,
            isProject: false,
            kind: bucketKind(type: metric.measurementType, unit: metric.unit),
            sessions: metric.sessions
        )
    }

    static func source(of project: Project) -> ContributionSource {
        ContributionSource(
            name: project.name,
            isProject: true,
            kind: bucketKind(type: project.metric?.measurementType ?? .duration, unit: project.metric?.unit),
            sessions: project.sessions
        )
    }

    static func bucketKind(
        type: MeasurementType,
        unit: String?
    ) -> RollupBucket.Kind {
        switch type {
        case .duration:
            return .duration
        case .count:
            let trimmed = (unit ?? "").trimmingCharacters(in: .whitespaces)
            return trimmed.isEmpty ? .entries : .count(unit: trimmed)
        case .binary:
            // Each done day is one session, so the unitless "entries" bucket
            // already totals binary effort as a day count.
            return .entries
        }
    }

    static func bucket(
        over sessions: [Session],
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

    static func merge(_ buckets: [RollupBucket]) -> [RollupBucket] {
        mergeByUnit(buckets, kind: \.kind) { $0.adding($1) }
    }
}
