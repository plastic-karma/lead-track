import Foundation

/// Device-local opt-in and identifiers only: no narrative or photo bytes are
/// copied into preferences or shared with notifications, widgets, or Watch.
struct MomentRediscoveryPreferences: Codable {
    static let enabledKey = "momentRediscoveryEnabled"
    static let stateKey = "momentRediscoveryState"

    var selections: [String: String] = [:]
    var dismissedPeriods: Set<String> = []
    var excludedMoments: Set<UUID> = []

    /// A live Week ends at now; changing seconds must not create a new review.
    /// Only automatic identity is day-normalized, never the history interval.
    static func periodKey(_ period: DateInterval, calendar: Calendar = .current) -> String {
        let start = calendar.startOfDay(for: period.start).timeIntervalSinceReferenceDate
        let end = calendar.startOfDay(for: period.end).timeIntervalSinceReferenceDate
        return "\(start)/\(end)"
    }

    /// Unreadable privacy state fails closed rather than forgetting exclusions.
    static func decode(_ data: Data) -> MomentRediscoveryPreferences? {
        guard !data.isEmpty else { return MomentRediscoveryPreferences() }
        return try? JSONDecoder().decode(Self.self, from: data)
    }

    func encoded() -> Data? {
        try? JSONEncoder().encode(self)
    }

    mutating func dismiss(period: DateInterval) {
        dismissedPeriods.insert(Self.periodKey(period))
    }

    mutating func exclude(_ moment: Moment, period: DateInterval) {
        if let id = moment.stableID { excludedMoments.insert(id) }
        dismiss(period: period)
    }
}
