import Foundation

// Creation-time invariants. Every intention is born through `make`, which
// rejects the combinations the feature deliberately refuses to model — the
// guard rails that keep an intention from collapsing into a goal, a habit
// tracker, or a todo item.

extension Intention {
    enum ValidationError: Error, Equatable {
        /// Reflective intentions carry no machinery at all: no target, no
        /// perDay, no ticks, no metric, no mode.
        case reflectiveCarriesMachinery
        /// Counted intentions are advanced by hand; a metric or mode belongs
        /// to the derived kind.
        case countedCarriesDerivedMachinery
        /// Derived intentions need both a metric and a mode.
        case derivedMissingMetricOrMode
        /// A weekly target must be a whole number ≥ 1 (counted and
        /// session-count), or simply > 0 (value sum).
        case invalidTarget
        /// perDay applies to counted intentions, or derived ones counting
        /// sessions. "30 min every day" is `Metric.dailyGoal` territory, and
        /// a nightly done/not-done is a `binary` metric's job.
        case perDayKindUnsupported
        /// Per-day intentions are implicitly once per day; multiplicity is
        /// unsupported.
        case perDayCarriesTarget
        /// A binary metric marks days done and tracks no quantity, so only
        /// `sessionCount` can derive from it.
        case binaryMetricRequiresSessionCount
    }

    /// The one validated way to create an intention. It attaches to the
    /// calendar week containing `createdAt` — a review closing last week
    /// naturally sets intentions for the week now underway — and to exactly
    /// one aspiration: no standalone intentions, ever.
    static func make(
        title: String,
        kind: IntentionKind,
        aspiration: Aspiration,
        derivedMode: DerivedMode? = nil,
        metric: Metric? = nil,
        perDay: Bool = false,
        target: Double? = nil,
        createdAt: Date = .now,
        calendar: Calendar = .current
    ) throws -> Intention {
        try validate(kind: kind, derivedMode: derivedMode, metric: metric, perDay: perDay, target: target)
        return Intention(
            title: title,
            kind: kind,
            aspiration: aspiration,
            derivedMode: derivedMode,
            metric: metric,
            perDay: perDay,
            target: target,
            weekStart: weekStart(containing: createdAt, calendar: calendar),
            createdAt: createdAt
        )
    }

    /// Whether a shape would pass `make`, without constructing anything —
    /// what a creation form's save button checks on every keystroke (a
    /// transient model instance would risk being auto-inserted through its
    /// relationships).
    static func isValidShape(
        kind: IntentionKind,
        derivedMode: DerivedMode? = nil,
        metric: Metric? = nil,
        perDay: Bool = false,
        target: Double? = nil
    ) -> Bool {
        (try? validate(kind: kind, derivedMode: derivedMode, metric: metric, perDay: perDay, target: target)) != nil
    }
}

// MARK: - Rules

private extension Intention {
    static func validate(
        kind: IntentionKind,
        derivedMode: DerivedMode?,
        metric: Metric?,
        perDay: Bool,
        target: Double?
    ) throws {
        switch kind {
        case .reflective:
            guard target == nil, !perDay, metric == nil, derivedMode == nil else {
                throw ValidationError.reflectiveCarriesMachinery
            }
        case .counted:
            guard metric == nil, derivedMode == nil else {
                throw ValidationError.countedCarriesDerivedMachinery
            }
            try validateTarget(target, wholeNumber: true, perDay: perDay)
        case .derived:
            try validateDerived(mode: derivedMode, metric: metric, perDay: perDay, target: target)
        }
    }

    static func validateDerived(
        mode: DerivedMode?,
        metric: Metric?,
        perDay: Bool,
        target: Double?
    ) throws {
        guard let mode, metric != nil else {
            throw ValidationError.derivedMissingMetricOrMode
        }
        if metric?.measurementType == .binary, mode == .valueSum {
            throw ValidationError.binaryMetricRequiresSessionCount
        }
        if perDay, mode == .valueSum {
            throw ValidationError.perDayKindUnsupported
        }
        try validateTarget(target, wholeNumber: mode == .sessionCount, perDay: perDay)
    }

    /// Shared target rule: per-day intentions carry none (implicitly once per
    /// day); weekly ones need a positive target, whole-numbered when it
    /// counts discrete acts.
    static func validateTarget(_ target: Double?, wholeNumber: Bool, perDay: Bool) throws {
        if perDay {
            guard target == nil else { throw ValidationError.perDayCarriesTarget }
            return
        }
        guard let target, target > 0, !wholeNumber || (target.rounded() == target && target >= 1) else {
            throw ValidationError.invalidTarget
        }
    }
}
