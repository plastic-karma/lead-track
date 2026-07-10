import Foundation

/// The permanent machinery a well-worn intention is offered to become.
/// Permanence is earned: the offer appears only when setting the intention
/// again would make the chain three consecutive weeks, and it always maps
/// onto machinery the app already has — never new machinery of its own.
/// Reflective intentions are never offered; some commitments should stay
/// unmeasured.
enum IntentionPromotion: Equatable {
    /// Set `weeklyGoal` on the linked metric, prefilled from the target.
    case weeklyGoal
    /// Set `dailyGoal` on the linked metric.
    case dailyGoal
    /// Create a count metric named from the title, attached to the aspiration.
    case countMetric
    /// Create a binary metric — the app's native permanent daily habit —
    /// attached to the aspiration.
    case binaryMetric
}

/// The lifecycle moves that outlive a single week: the explicit "set again"
/// renewal, and the predecessor-chain bookkeeping a promotion offer is earned
/// along. Renewal is always deliberate — nothing here auto-renews.
enum IntentionRenewal {
    /// Closes `source` without a verdict (the numbers stood on their own) and
    /// clones it into the calendar week containing `now`. The clone keeps the
    /// commitment — title, kind, mode, perDay, metric, target, and the daily
    /// question — and carries the chain forward via `predecessorID`,
    /// `promotionDismissed` included. The caller inserts the clone into its
    /// context (and, from UI, should also arm the clone's question via
    /// `NotificationService.scheduleQuestion(for:)`; until then the next
    /// foreground sweep picks it up).
    static func setAgain(
        _ source: Intention,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Intention {
        source.close(outcome: nil, at: now)
        let renewed = Intention(
            title: source.title,
            kind: source.kind,
            aspiration: source.aspiration,
            derivedMode: source.derivedMode,
            metric: source.metric,
            perDay: source.perDay,
            target: source.target,
            weekStart: Intention.weekStart(containing: now, calendar: calendar),
            createdAt: now
        )
        renewed.predecessorID = source.stableID
        renewed.promotionDismissed = source.promotionDismissed
        renewed.applyQuestion(source.question)
        return renewed
    }

    /// How many consecutive weeks the commitment has been set, walking the
    /// `predecessorID` links through `all`. Chains are short; the walk is
    /// bounded and cycle-safe.
    static func chainLength(of intention: Intention, among all: [Intention]) -> Int {
        var byID: [UUID: Intention] = [:]
        for item in all {
            if let id = item.stableID { byID[id] = item }
        }
        var visited = Set(intention.stableID.map { [$0] } ?? [])
        var current = intention
        var length = 1
        while let predecessorID = current.predecessorID,
              let predecessor = byID[predecessorID],
              visited.insert(predecessorID).inserted
        {
            length += 1
            current = predecessor
        }
        return length
    }

    /// The offer setting `intention` again would surface at the review, or
    /// nil when none is due: the chain must reach three consecutive weeks
    /// with the renewal, and a chain that declined once is never asked again.
    static func offerOnSetAgain(of intention: Intention, among all: [Intention]) -> IntentionPromotion? {
        guard !intention.promotionDismissed,
              chainLength(of: intention, among: all) + 1 >= 3
        else { return nil }
        return offer(for: intention)
    }

    /// The promotion an intention's shape maps to, independent of chain
    /// length. Nil for reflective intentions, and for derived ones whose
    /// metric was removed (there is nothing left to set a goal on).
    static func offer(for intention: Intention) -> IntentionPromotion? {
        switch intention.kind {
        case .reflective:
            return nil
        case .counted:
            return intention.perDay ? .binaryMetric : .countMetric
        case .derived:
            guard intention.metric != nil else { return nil }
            return intention.perDay ? .dailyGoal : .weeklyGoal
        }
    }
}
