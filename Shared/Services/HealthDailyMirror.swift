import Foundation

/// Plans how a health-linked metric's mirrored sessions must change to match
/// the day totals just fetched from HealthKit. Pure planning — the sync
/// service applies the operations to the store. One value-session per day
/// mirrors that day's total; a day with nothing to show holds no session,
/// matching how hand-recorded metrics treat an empty day so streaks and
/// heatmaps agree.
enum HealthDailyMirror {
    /// One store change for a single day.
    enum Operation: Equatable {
        /// Insert a fresh mirrored session carrying the day's value.
        case insert(day: Date, value: Double)
        /// Rewrite the day's existing session to carry `value`.
        case update(day: Date, value: Double)
        /// Remove every session on the day — the figure vanished from
        /// HealthKit, or duplicates need collapsing before a re-insert.
        case delete(day: Date)
    }

    /// Diffs fetched day totals against the sessions currently mirrored in
    /// the window. Values are compared exactly: the reader rounds to whole
    /// canonical units, so an unchanged day plans no work. `existing` may
    /// carry several values for one day (never expected, but self-healing):
    /// such a day is wiped and re-inserted.
    static func plan(
        window: [Date],
        fetched: [Date: Double],
        existing: [Date: [Double]]
    ) -> [Operation] {
        window.flatMap { day in
            operations(
                day: day,
                value: fetched[day] ?? 0,
                current: existing[day] ?? []
            )
        }
    }

    /// The trailing day-starts the mirror keeps fresh, oldest first: the
    /// reference date's day and the `count - 1` days before it. Days that
    /// roll out of the window freeze with their last-synced values.
    static func window(
        days count: Int,
        endingOn reference: Date = .now,
        calendar: Calendar = .current
    ) -> [Date] {
        let today = calendar.startOfDay(for: reference)
        return (0 ..< max(count, 1)).reversed().compactMap {
            calendar.date(byAdding: .day, value: -$0, to: today)
        }
    }
}

// MARK: - Per-Day Rules

extension HealthDailyMirror {
    private static func operations(
        day: Date,
        value: Double,
        current: [Double]
    ) -> [Operation] {
        guard current.count <= 1 else {
            return rebuild(day: day, value: value)
        }
        guard let existingValue = current.first else {
            return value > 0 ? [.insert(day: day, value: value)] : []
        }
        return reconcile(day: day, value: value, existingValue: existingValue)
    }

    private static func rebuild(day: Date, value: Double) -> [Operation] {
        var operations: [Operation] = [.delete(day: day)]
        if value > 0 {
            operations.append(.insert(day: day, value: value))
        }
        return operations
    }

    private static func reconcile(
        day: Date,
        value: Double,
        existingValue: Double
    ) -> [Operation] {
        guard value > 0 else { return [.delete(day: day)] }
        return existingValue == value ? [] : [.update(day: day, value: value)]
    }
}
