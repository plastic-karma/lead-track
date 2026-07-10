import Foundation

/// Turns a `ReminderSchedule` into the concrete moments a metric should be
/// reminded on the soonest goal day. Pure Foundation, so it builds and
/// unit-tests on Linux; `NotificationService` wraps the returned dates in
/// notification triggers.
enum ReminderPlanner {
    /// The fire times for the soonest goal day that still has a moment ahead of
    /// `now` — today's remaining pings when any are left, otherwise the next
    /// non-rest day's full set. Empty when no goal day falls in the next week
    /// (every weekday excluded).
    static func nextFireDates(
        for schedule: ReminderSchedule,
        seed: UInt64,
        excludedWeekdays: Set<Int>,
        now: Date,
        calendar: Calendar = .current
    ) -> [Date] {
        let days = goalDays(from: now, excludedWeekdays: excludedWeekdays, calendar: calendar)
        for day in days {
            let fires = fireDates(for: schedule, on: day, seed: seed, calendar: calendar)
                .filter { $0 > now }
            if !fires.isEmpty {
                return fires
            }
        }
        return []
    }

    /// The concrete fire moments on a single day for this schedule.
    static func fireDates(
        for schedule: ReminderSchedule,
        on day: Date,
        seed: UInt64,
        calendar: Calendar
    ) -> [Date] {
        let minutes = fireMinutes(for: schedule, on: day, seed: seed, calendar: calendar)
        return minutes.compactMap { minute in
            calendar.date(bySettingHour: minute / 60, minute: minute % 60, second: 0, of: day)
        }
    }

    /// Minutes-since-midnight the schedule fires at on `day`, sorted ascending.
    static func fireMinutes(
        for schedule: ReminderSchedule,
        on day: Date,
        seed: UInt64,
        calendar: Calendar
    ) -> [Int] {
        switch schedule.mode {
        case .fixed:
            return fixedMinutes(schedule, calendar: calendar)
        case .random:
            return randomMinutes(schedule, on: day, seed: seed, calendar: calendar)
        }
    }

    /// `count` distinct minutes drawn uniformly from the inclusive range,
    /// sorted ascending. Clamps the count to the range's width and returns a
    /// single minute for a degenerate range. Deterministic for a given seed, so
    /// a day's random pings stay put across reschedules.
    static func randomMinutes(in range: ClosedRange<Int>, count: Int, seed: UInt64) -> [Int] {
        let width = range.upperBound - range.lowerBound
        guard width > 0, count > 0 else { return [range.lowerBound] }
        let wanted = min(count, width + 1)
        var generator = SeededGenerator(seed: seed)
        var chosen = Set<Int>()
        while chosen.count < wanted {
            chosen.insert(Int.random(in: range, using: &generator))
        }
        return chosen.sorted()
    }
}

// MARK: - Mode Math

extension ReminderPlanner {
    private static func fixedMinutes(_ schedule: ReminderSchedule, calendar: Calendar) -> [Int] {
        let minutes = schedule.normalizedFixedTimes.map { minuteOfDay($0, calendar: calendar) }
        return Array(Set(minutes)).sorted()
    }

    private static func randomMinutes(
        _ schedule: ReminderSchedule,
        on day: Date,
        seed: UInt64,
        calendar: Calendar
    ) -> [Int] {
        let start = minuteOfDay(schedule.rangeStart, calendar: calendar)
        let end = minuteOfDay(schedule.rangeEnd, calendar: calendar)
        let dailySeed = mix(seed, dayOrdinal(day, calendar: calendar))
        return randomMinutes(
            in: min(start, end) ... max(start, end),
            count: schedule.clampedCount,
            seed: dailySeed
        )
    }
}

// MARK: - Day & Time Helpers

extension ReminderPlanner {
    /// Today through a week out, dropping rest days, as start-of-day dates.
    private static func goalDays(
        from now: Date,
        excludedWeekdays: Set<Int>,
        calendar: Calendar
    ) -> [Date] {
        let start = calendar.startOfDay(for: now)
        return (0 ... 7)
            .compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
            .filter { !excludedWeekdays.contains(calendar.component(.weekday, from: $0)) }
    }

    // The three helpers below are internal (not private) so
    // `IntentionQuestionPlanner` draws from the same per-day seed formula —
    // determinism has one source of truth.

    static func minuteOfDay(_ date: Date, calendar: Calendar) -> Int {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }

    static func dayOrdinal(_ date: Date, calendar: Calendar) -> UInt64 {
        UInt64(calendar.ordinality(of: .day, in: .era, for: date) ?? 0)
    }

    static func mix(_ seed: UInt64, _ salt: UInt64) -> UInt64 {
        (seed ^ salt) &* 0x9E37_79B9_7F4A_7C15
    }
}

// MARK: - Seeded RNG

extension ReminderPlanner {
    /// A tiny seedable PRNG (SplitMix64). `SystemRandomNumberGenerator` can't be
    /// seeded, and reproducing a day's random pings needs the same seed to
    /// yield the same sequence.
    struct SeededGenerator: RandomNumberGenerator {
        private var state: UInt64

        init(seed: UInt64) {
            state = seed
        }

        mutating func next() -> UInt64 {
            state = state &+ 0x9E37_79B9_7F4A_7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            return z ^ (z >> 31)
        }
    }
}

// MARK: - Stable Seed

extension UUID {
    /// A launch-stable 64-bit seed folded from the raw bytes (FNV-1a). Unlike
    /// `hashValue`, which Swift salts per process, this is identical across app
    /// launches, so a metric's random pings don't reshuffle when the app is
    /// relaunched.
    var stableSeed: UInt64 {
        withUnsafeBytes(of: uuid) { bytes in
            bytes.reduce(UInt64(0xCBF2_9CE4_8422_2325)) {
                ($0 ^ UInt64($1)) &* 0x0000_0100_0000_01B3
            }
        }
    }
}
