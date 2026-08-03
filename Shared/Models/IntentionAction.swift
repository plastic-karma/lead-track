import Foundation
#if canImport(SwiftData)
import SwiftData
#endif

/// The editable value behind one concrete action scheduled in an intention's
/// week. It stays separate from the persisted model so creation can draft
/// actions before the intention itself exists in a ModelContext.
struct IntentionActionDraft: Identifiable, Equatable {
    static let minimumDuration: TimeInterval = 15 * 60
    static let defaultDuration: TimeInterval = 30 * 60

    let id: UUID
    var title: String
    var startsAt: Date
    var endsAt: Date

    init(
        id: UUID = UUID(),
        title: String = "",
        startsAt: Date,
        endsAt: Date
    ) {
        self.id = id
        self.title = title
        self.startsAt = startsAt
        self.endsAt = endsAt
    }
}

// MARK: - Validation & Defaults

extension IntentionActionDraft {
    var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Trims the user text and rejects an event shorter than the editor's
    /// minimum duration.
    var normalized: Self? {
        guard !trimmedTitle.isEmpty,
              endsAt.timeIntervalSince(startsAt) >= Self.minimumDuration
        else { return nil }
        var copy = self
        copy.title = trimmedTitle
        return copy
    }

    /// Actions belong to the same half-open calendar week as their intention.
    /// An event may end exactly at the next week's boundary, but never begin
    /// there or extend beyond it.
    func normalized(in week: DateInterval) -> Self? {
        guard let normalized,
              normalized.startsAt >= week.start,
              normalized.startsAt < week.end,
              normalized.endsAt <= week.end
        else { return nil }
        return normalized
    }

    /// Validates a whole set atomically so callers never silently discard an
    /// invalid row or accept duplicate stable IDs (which would collide both
    /// in SwiftData and in iCalendar UIDs).
    static func validated(_ drafts: [Self]) -> [Self]? {
        guard Set(drafts.map(\.id)).count == drafts.count else { return nil }
        let normalized = drafts.compactMap(\.normalized)
        return normalized.count == drafts.count ? normalized : nil
    }

    static func validated(_ drafts: [Self], in week: DateInterval) -> [Self]? {
        guard Set(drafts.map(\.id)).count == drafts.count else { return nil }
        let normalized = drafts.compactMap { $0.normalized(in: week) }
        return normalized.count == drafts.count ? normalized : nil
    }

    /// Repairs an older or externally-corrupted time range before binding it
    /// to DatePicker, whose selection must stay inside its ClosedRange.
    func clamped(in week: DateInterval) -> Self {
        let latestStart = max(
            week.start,
            week.end.addingTimeInterval(-Self.minimumDuration)
        )
        var copy = self
        copy.startsAt = min(max(startsAt, week.start), latestStart)
        copy.endsAt = min(
            max(endsAt, copy.startsAt.addingTimeInterval(Self.minimumDuration)),
            week.end
        )
        return copy
    }

    /// A new row starts at the next quarter hour and lasts 30 minutes. Near
    /// the end of the week it shifts back just enough to remain in the week.
    static func makeDefault(
        in week: DateInterval,
        after previousEnd: Date? = nil,
        now: Date = .now
    ) -> Self {
        let anchor = max(now, previousEnd ?? now)
        let candidate = roundedUpToQuarterHour(anchor)
        let latestStart = max(week.start, week.end.addingTimeInterval(-defaultDuration))
        let startsAt = min(max(candidate, week.start), latestStart)
        let endsAt = min(startsAt.addingTimeInterval(defaultDuration), week.end)
        return Self(startsAt: startsAt, endsAt: endsAt)
    }

    private static func roundedUpToQuarterHour(_ date: Date) -> Date {
        let step = 15 * 60.0
        let interval = date.timeIntervalSinceReferenceDate
        return Date(timeIntervalSinceReferenceDate: (interval / step).rounded(.up) * step)
    }
}

// One persisted calendar action. It deliberately points at its intention by
// stable UUID rather than a SwiftData relationship: the released Intention
// model stays byte-for-byte unchanged while V3 adds this standalone entity.
// Actions are never completion-tracked; Calendar receives a snapshot of them.
#if canImport(SwiftData)
@Model
#endif
final class IntentionAction {
    #if canImport(SwiftData)
    #Unique<IntentionAction>([\.stableID])
    #endif
    var stableID: UUID
    var intentionID: UUID
    var title: String
    var startsAt: Date
    var endsAt: Date

    init(intentionID: UUID, draft: IntentionActionDraft) {
        stableID = draft.id
        self.intentionID = intentionID
        title = draft.trimmedTitle
        startsAt = draft.startsAt
        endsAt = draft.endsAt
    }
}

extension IntentionAction {
    var draft: IntentionActionDraft {
        IntentionActionDraft(
            id: stableID,
            title: title,
            startsAt: startsAt,
            endsAt: endsAt
        )
    }

    func apply(_ draft: IntentionActionDraft) {
        title = draft.trimmedTitle
        startsAt = draft.startsAt
        endsAt = draft.endsAt
    }

    static func calendarOrder(_ lhs: IntentionAction, _ rhs: IntentionAction) -> Bool {
        if lhs.startsAt != rhs.startsAt { return lhs.startsAt < rhs.startsAt }
        if lhs.endsAt != rhs.endsAt { return lhs.endsAt < rhs.endsAt }
        if lhs.title != rhs.title { return lhs.title < rhs.title }
        return lhs.stableID.uuidString < rhs.stableID.uuidString
    }
}
