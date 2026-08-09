import Foundation

enum AdditionalReviewCycleKind: String, Codable, CaseIterable {
    case monthly
    case quarterly
    case yearly
    case custom
}

enum AdditionalReviewCycleUnit: String, Codable, CaseIterable {
    case days
    case months

    var maximumInterval: Int {
        switch self {
        case .days: 365
        case .months: 120
        }
    }
}

/// A user-defined recurring review alongside the fixed Weekly Review.
/// Configuration is value data: sessions remain the source of every figure.
struct AdditionalReview: Codable, Equatable, Hashable, Identifiable {
    var id: UUID
    var name: String
    var cycle: AdditionalReviewCycleKind
    var customUnit: AdditionalReviewCycleUnit
    var customInterval: Int
    var anchor: Date
    var hour: Int
    var minute: Int
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        cycle: AdditionalReviewCycleKind,
        customUnit: AdditionalReviewCycleUnit = .days,
        customInterval: Int = 10,
        anchor: Date = .now,
        hour: Int = 9,
        minute: Int = 0,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.cycle = cycle
        self.customUnit = customUnit
        self.customInterval = customInterval
        self.anchor = anchor
        self.hour = hour
        self.minute = minute
        self.createdAt = createdAt
    }

    var boundedInterval: Int {
        min(max(customInterval, 1), customUnit.maximumInterval)
    }

    var boundedHour: Int {
        min(max(hour, 0), 23)
    }

    var boundedMinute: Int {
        min(max(minute, 0), 59)
    }
}

/// UserDefaults is appropriate for this small configuration collection: it
/// stays available to notification planning without coupling schedules to the
/// SwiftData store that holds tracked effort.
enum AdditionalReviewStore {
    static let key = "additionalReviews"
    /// Keys written only by the withdrawn first implementation, which
    /// incorrectly replaced the Weekly Review instead of adding alongside it.
    private static let legacyCycleKey = "weeklyReviewCycle"
    private static let legacyUnitKey = "weeklyReviewCustomUnit"
    private static let legacyIntervalKey = "weeklyReviewCustomInterval"
    private static let legacyAnchorKey = "weeklyReviewCustomAnchor"

    static func reviews(in defaults: UserDefaults = .standard) -> [AdditionalReview] {
        if let data = defaults.data(forKey: key) {
            return decode(data)
        }
        return migrateWithdrawnSchedule(in: defaults)
    }

    static func decode(_ data: Data) -> [AdditionalReview] {
        guard !data.isEmpty else { return [] }
        return (try? JSONDecoder().decode([AdditionalReview].self, from: data)) ?? []
    }

    static func encode(_ reviews: [AdditionalReview]) -> Data {
        (try? JSONEncoder().encode(reviews)) ?? Data()
    }

    static func save(
        _ reviews: [AdditionalReview],
        in defaults: UserDefaults = .standard
    ) {
        defaults.set(encode(reviews), forKey: key)
    }

    /// Preserves a schedule configured in the withdrawn TestFlight build as
    /// one additional review, then removes those obsolete keys. Weekly keeps
    /// its original enabled/day/time contract throughout.
    private static func migrateWithdrawnSchedule(
        in defaults: UserDefaults
    ) -> [AdditionalReview] {
        guard let rawCycle = defaults.string(forKey: legacyCycleKey),
              rawCycle != "weekly",
              let cycle = AdditionalReviewCycleKind(rawValue: rawCycle)
        else {
            removeLegacyKeys(in: defaults)
            return []
        }
        let unit = AdditionalReviewCycleUnit(
            rawValue: defaults.string(forKey: legacyUnitKey) ?? ""
        ) ?? .days
        let interval = defaults.object(forKey: legacyIntervalKey) as? Int ?? 10
        let storedAnchor = defaults.double(forKey: legacyAnchorKey)
        let anchor = storedAnchor > 0
            ? Date(timeIntervalSinceReferenceDate: storedAnchor)
            : Date.now
        let review = AdditionalReview(
            name: migratedName(cycle: cycle, unit: unit, interval: interval),
            cycle: cycle,
            customUnit: unit,
            customInterval: interval,
            anchor: anchor,
            hour: WeeklyReviewSettings.hour(in: defaults),
            minute: WeeklyReviewSettings.minute(in: defaults)
        )
        save([review], in: defaults)
        removeLegacyKeys(in: defaults)
        return [review]
    }

    private static func migratedName(
        cycle: AdditionalReviewCycleKind,
        unit: AdditionalReviewCycleUnit,
        interval: Int
    ) -> String {
        switch cycle {
        case .monthly: "Monthly Review"
        case .quarterly: "Quarterly Review"
        case .yearly: "Yearly Review"
        case .custom:
            "\(interval)-\(unit == .days ? "Day" : "Month") Review"
        }
    }

    private static func removeLegacyKeys(in defaults: UserDefaults) {
        [legacyCycleKey, legacyUnitKey, legacyIntervalKey, legacyAnchorKey]
            .forEach(defaults.removeObject)
    }

    static func upserting(
        _ review: AdditionalReview,
        in reviews: [AdditionalReview]
    ) -> [AdditionalReview] {
        guard let index = reviews.firstIndex(where: { $0.id == review.id }) else {
            return reviews + [review]
        }
        var updated = reviews
        updated[index] = review
        return updated
    }

    static func removing(
        id: UUID,
        from reviews: [AdditionalReview]
    ) -> [AdditionalReview] {
        reviews.filter { $0.id != id }
    }
}
