import Foundation

/// A quiet return to the user's own words, never a generated interpretation.
/// A period must already contain narrative or effort under the same active why.
/// The first selection (including silence) is pinned for the represented days.
enum MomentRediscovery {
    static let minimumAgeDays = 90

    static func prepare(
        history: RetrospectiveHistory,
        period: DateInterval,
        preferences: inout MomentRediscoveryPreferences,
        enabled: Bool
    ) {
        guard enabled else { return }
        let key = MomentRediscoveryPreferences.periodKey(period)
        guard preferences.selections[key] == nil else { return }
        let moment = candidates(history: history, period: period, preferences: preferences).first
        preferences.selections[key] = moment?.stableID?.uuidString ?? ""
    }

    static func selected(
        history: RetrospectiveHistory,
        period: DateInterval,
        preferences: MomentRediscoveryPreferences,
        enabled: Bool
    ) -> Moment? {
        let key = MomentRediscoveryPreferences.periodKey(period)
        guard enabled, !preferences.dismissedPeriods.contains(key),
              let selectedID = preferences.selections[key], !selectedID.isEmpty
        else { return nil }
        let moment = history.aspirations.lazy.filter { !$0.isArchived }
            .flatMap(\.moments).first { $0.stableID?.uuidString == selectedID }
        let cutoff = period.start.addingTimeInterval(-Double(minimumAgeDays) * 86400)
        guard let moment, let aspiration = moment.aspiration,
              isEligible(moment, before: cutoff, preferences: preferences),
              RetrospectiveReader.hasHistory(for: aspiration, period: period)
        else { return nil }
        return moment
    }

    private static func candidates(
        history: RetrospectiveHistory,
        period: DateInterval,
        preferences: MomentRediscoveryPreferences
    ) -> [Moment] {
        let cutoff = period.start.addingTimeInterval(-Double(minimumAgeDays) * 86400)
        return history.aspirations.filter { !$0.isArchived }.filter { aspiration in
            RetrospectiveReader.hasHistory(for: aspiration, period: period)
        }.flatMap(\.moments).filter {
            isEligible($0, before: cutoff, preferences: preferences)
        }.sorted {
            if $0.occurredAt != $1.occurredAt { return $0.occurredAt > $1.occurredAt }
            return $0.stableIdentity < $1.stableIdentity
        }
    }

    private static func isEligible(
        _ moment: Moment,
        before cutoff: Date,
        preferences: MomentRediscoveryPreferences
    ) -> Bool {
        guard let id = moment.stableID, !preferences.excludedMoments.contains(id) else { return false }
        return moment.occurredAt <= cutoff
            && !moment.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
