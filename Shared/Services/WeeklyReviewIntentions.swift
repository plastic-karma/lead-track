import Foundation

// The intention layer of the weekly review, assembled the same additive way
// as the aspiration lens: with zero intentions the review is byte-identical
// to the review before intentions existed — never a fork.

extension WeeklyReview {
    /// One unclosed intention from the most recently completed week, awaiting
    /// its closure decision at this review. The accumulation is presented as
    /// fact — no judgment copy, no derived outcome label; the numbers stand.
    struct IntentionClosure: Identifiable {
        /// The intention's stable identity, mapped back to the model when a
        /// decision is written.
        let id: String
        /// The owning aspiration's stable identity, for grouping under its
        /// card.
        let aspirationID: String
        let title: String
        let kind: IntentionKind
        let perDay: Bool
        /// "4 of 7 days" / "2 of 3" / "1h 40m of 4h 00m". Nil for reflective
        /// intentions (closed by judgment, not numbers) and for derived ones
        /// whose metric was removed.
        let progressText: String?
        /// A derived intention whose metric was deleted mid-week; only
        /// letting go is offered.
        let sourceRemoved: Bool
        /// The promotion that setting it again would earn, nil when none is
        /// due.
        let promotion: IntentionPromotion?
    }

    /// The closure list: unclosed intentions from the single most recently
    /// completed calendar week only, in creation order. Older unclosed
    /// intentions freeze silently as history — they are never queued up
    /// across reviews or surfaced as debt — and browsing earlier weeks
    /// (`weeksBack > 0`) offers no closures at all.
    static func intentionClosures(
        from intentions: [Intention],
        weeksBack: Int = 0,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [IntentionClosure] {
        guard weeksBack == 0, !intentions.isEmpty,
              let currentWeek = calendar.dateInterval(of: .weekOfYear, for: now),
              let lastWeekAnchor = calendar.date(byAdding: .weekOfYear, value: -1, to: currentWeek.start)
        else { return [] }
        let lastWeekStart = Intention.weekStart(containing: lastWeekAnchor, calendar: calendar)
        return intentions
            .filter { $0.isOpen && $0.weekStart == lastWeekStart }
            .sorted { $0.createdAt < $1.createdAt }
            .map { closure(of: $0, among: intentions, calendar: calendar) }
    }

    private static func closure(
        of intention: Intention,
        among all: [Intention],
        calendar: Calendar
    ) -> IntentionClosure {
        IntentionClosure(
            id: intention.stableIdentity,
            aspirationID: intention.aspiration.map(\.stableIdentity) ?? "",
            title: intention.title,
            kind: intention.kind,
            perDay: intention.perDay,
            progressText: IntentionProgress.compute(for: intention, calendar: calendar)?.text,
            sourceRemoved: intention.isSourceRemoved,
            promotion: IntentionRenewal.offerOnSetAgain(of: intention, among: all)
        )
    }
}
