import Foundation

enum ReviewCycleKind: String, CaseIterable {
    case weekly
    case monthly
    case quarterly
    case yearly
    case custom
}

enum ReviewCycleUnit: String, CaseIterable {
    case days
    case months

    var maximumInterval: Int {
        switch self {
        case .days: 365
        case .months: 120
        }
    }
}

enum ReviewCycle: Equatable {
    case weekly(weekday: Int)
    case monthly
    case quarterly
    case yearly
    case everyDays(Int, anchor: Date)
    case everyMonths(Int, anchor: Date)
}

/// The review notification's UserDefaults contract and migration boundary.
/// Existing installs have no cycle key, so they remain weekly on their saved
/// weekday. Custom cycles are anchored when chosen; preset month-based cycles
/// follow calendar boundaries.
enum WeeklyReviewSettings {
    static let enabledKey = "weeklyReviewEnabled"
    static let dayKey = "weeklyReviewDay"
    static let hourKey = "weeklyReviewHour"
    static let minuteKey = "weeklyReviewMinute"
    static let cycleKey = "weeklyReviewCycle"
    static let customUnitKey = "weeklyReviewCustomUnit"
    static let customIntervalKey = "weeklyReviewCustomInterval"
    static let customAnchorKey = "weeklyReviewCustomAnchor"

    static let defaultCycle = ReviewCycleKind.weekly
    static let defaultCustomUnit = ReviewCycleUnit.days
    static let defaultCustomInterval = 10
    /// Monday, in `Calendar`'s 1 = Sunday weekday numbering.
    static let defaultDay = 2
    static let defaultHour = 9
    static let defaultMinute = 0

    static func isEnabled(in defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: enabledKey)
    }

    static func cycleKind(in defaults: UserDefaults = .standard) -> ReviewCycleKind {
        guard let rawValue = defaults.string(forKey: cycleKey) else { return defaultCycle }
        return ReviewCycleKind(rawValue: rawValue) ?? defaultCycle
    }

    static func customUnit(in defaults: UserDefaults = .standard) -> ReviewCycleUnit {
        guard let rawValue = defaults.string(forKey: customUnitKey) else { return defaultCustomUnit }
        return ReviewCycleUnit(rawValue: rawValue) ?? defaultCustomUnit
    }

    static func customInterval(in defaults: UserDefaults = .standard) -> Int {
        let unit = customUnit(in: defaults)
        let stored = integer(forKey: customIntervalKey, default: defaultCustomInterval, in: defaults)
        return min(max(stored, 1), unit.maximumInterval)
    }

    static func day(in defaults: UserDefaults = .standard) -> Int {
        min(max(integer(forKey: dayKey, default: defaultDay, in: defaults), 1), 7)
    }

    static func hour(in defaults: UserDefaults = .standard) -> Int {
        min(max(integer(forKey: hourKey, default: defaultHour, in: defaults), 0), 23)
    }

    static func minute(in defaults: UserDefaults = .standard) -> Int {
        min(max(integer(forKey: minuteKey, default: defaultMinute, in: defaults), 0), 59)
    }

    static func cycle(
        in defaults: UserDefaults = .standard,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> ReviewCycle {
        switch cycleKind(in: defaults) {
        case .weekly: .weekly(weekday: day(in: defaults))
        case .monthly: .monthly
        case .quarterly: .quarterly
        case .yearly: .yearly
        case .custom:
            customCycle(in: defaults, now: now, calendar: calendar)
        }
    }

    private static func customCycle(
        in defaults: UserDefaults,
        now: Date,
        calendar: Calendar
    ) -> ReviewCycle {
        let interval = customInterval(in: defaults)
        let storedAnchor = defaults.double(forKey: customAnchorKey)
        let anchor = storedAnchor > 0
            ? Date(timeIntervalSinceReferenceDate: storedAnchor)
            : calendar.startOfDay(for: now)
        switch customUnit(in: defaults) {
        case .days: return .everyDays(interval, anchor: anchor)
        case .months: return .everyMonths(interval, anchor: anchor)
        }
    }

    private static func integer(
        forKey key: String,
        default fallback: Int,
        in defaults: UserDefaults
    ) -> Int {
        defaults.object(forKey: key) as? Int ?? fallback
    }
}

/// Calendar-safe review boundaries. Every result is the first day of a new
/// period at the chosen wall-clock time; day cycles therefore stay fixed
/// through daylight-saving changes instead of drifting by 24-hour seconds.
enum ReviewSchedule {
    static let notificationCount = 8

    private struct Timing {
        let now: Date
        let hour: Int
        let minute: Int
        let calendar: Calendar
    }

    static func fireDates(
        for cycle: ReviewCycle,
        after now: Date = .now,
        hour: Int,
        minute: Int,
        count: Int = notificationCount,
        calendar: Calendar = .current
    ) -> [Date] {
        let timing = Timing(now: now, hour: hour, minute: minute, calendar: calendar)
        guard count > 0, let first = firstDate(for: cycle, timing: timing)
        else { return [] }
        var dates = [first]
        while dates.count < count {
            guard let next = nextDate(after: dates[dates.count - 1], for: cycle, calendar: calendar)
            else { break }
            dates.append(next)
        }
        return dates
    }

    private static func firstDate(
        for cycle: ReviewCycle,
        timing: Timing
    ) -> Date? {
        switch cycle {
        case let .weekly(weekday):
            return weeklyBoundary(weekday: weekday, timing: timing)
        case .monthly:
            return fixedMonthBoundary(stride: 1, timing: timing)
        case .quarterly:
            return fixedMonthBoundary(stride: 3, timing: timing)
        case .yearly:
            return fixedMonthBoundary(stride: 12, timing: timing)
        case let .everyDays(interval, anchor):
            return customBoundary(
                component: .day, interval: interval, anchor: anchor, timing: timing
            )
        case let .everyMonths(interval, anchor):
            return customBoundary(
                component: .month, interval: interval, anchor: anchor, timing: timing
            )
        }
    }

    private static func weeklyBoundary(
        weekday: Int,
        timing: Timing
    ) -> Date? {
        var components = DateComponents()
        components.weekday = weekday
        components.hour = timing.hour
        components.minute = timing.minute
        return timing.calendar.nextDate(
            after: timing.now, matching: components, matchingPolicy: .nextTime
        )
    }

    private static func fixedMonthBoundary(
        stride: Int,
        timing: Timing
    ) -> Date? {
        let calendar = timing.calendar
        let components = calendar.dateComponents([.year, .month], from: timing.now)
        guard let year = components.year, let month = components.month else { return nil }
        let alignedMonth = month - ((month - 1) % stride)
        guard let day = calendar.date(from: DateComponents(year: year, month: alignedMonth, day: 1)),
              let candidate = date(on: day, timing: timing)
        else { return nil }
        if candidate > timing.now { return candidate }
        guard let nextDay = calendar.date(byAdding: .month, value: stride, to: day) else { return nil }
        return date(on: nextDay, timing: timing)
    }

    private static func customBoundary(
        component: Calendar.Component,
        interval: Int,
        anchor: Date,
        timing: Timing
    ) -> Date? {
        guard interval > 0 else { return nil }
        let calendar = timing.calendar
        let anchorDay = component == .month
            ? monthStart(containing: anchor, calendar: calendar)
            : calendar.startOfDay(for: anchor)
        guard var day = calendar.date(byAdding: component, value: interval, to: anchorDay),
              var candidate = date(on: day, timing: timing)
        else { return nil }
        while candidate <= timing.now {
            guard let advanced = calendar.date(byAdding: component, value: interval, to: day),
                  let advancedCandidate = date(on: advanced, timing: timing)
            else { return nil }
            day = advanced
            candidate = advancedCandidate
        }
        return candidate
    }

    private static func nextDate(
        after date: Date,
        for cycle: ReviewCycle,
        calendar: Calendar
    ) -> Date? {
        switch cycle {
        case .weekly:
            calendar.date(byAdding: .day, value: 7, to: date)
        case .monthly:
            calendar.date(byAdding: .month, value: 1, to: date)
        case .quarterly:
            calendar.date(byAdding: .month, value: 3, to: date)
        case .yearly:
            calendar.date(byAdding: .year, value: 1, to: date)
        case let .everyDays(interval, _):
            calendar.date(byAdding: .day, value: interval, to: date)
        case let .everyMonths(interval, _):
            calendar.date(byAdding: .month, value: interval, to: date)
        }
    }

    private static func monthStart(containing date: Date, calendar: Calendar) -> Date {
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? calendar.startOfDay(for: date)
    }

    private static func date(on day: Date, timing: Timing) -> Date? {
        var components = timing.calendar.dateComponents([.year, .month, .day], from: day)
        components.hour = timing.hour
        components.minute = timing.minute
        return timing.calendar.date(from: components)
    }
}
