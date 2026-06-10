import Foundation

enum InsightGenerator {
    static func generate(
        for metric: Metric,
        currentStart: Date,
        previousStart: Date,
        now: Date = .now
    ) -> [Insight] {
        let nonRunning = metric.sessions.filter { !$0.isRunning }
        let current = nonRunning.filter {
            $0.startedAt >= currentStart && $0.startedAt <= now
        }
        let previous = nonRunning.filter {
            $0.startedAt >= previousStart && $0.startedAt < currentStart
        }
        let raw = collectRaw(metric: metric, current: current, previous: previous, all: nonRunning)
        return applyCategoryCaps(raw)
    }
}

// MARK: - Collection & Ranking

private extension InsightGenerator {
    static func collectRaw(
        metric: Metric,
        current: [Session],
        previous: [Session],
        all: [Session]
    ) -> [Insight] {
        var results: [Insight] = []
        // Order matters — first insight per category wins the category cap.
        append(&results, detectStreak(metric: metric, sessions: all))
        append(&results, detectActiveDaysChange(current: current, previous: previous))
        append(&results, detectVolumeChange(metric: metric, current: current, previous: previous))
        append(&results, detectGoalHitRateChange(metric: metric, current: current, previous: previous))
        append(&results, detectDayOfWeekMode(sessions: current))
        append(&results, detectTimeOfDayMode(sessions: current))
        return results
    }

    static func append(_ results: inout [Insight], _ insight: Insight?) {
        if let insight { results.append(insight) }
    }

    static func applyCategoryCaps(_ insights: [Insight]) -> [Insight] {
        var seen: Set<InsightCategory> = []
        var result: [Insight] = []
        for insight in insights where seen.insert(insight.category).inserted {
            result.append(insight)
        }
        return result
    }
}

// MARK: - Detector Thresholds

private extension InsightGenerator {
    static let minTimeOfDaySessions = 4
    static let timeOfDayDominance = 0.5
    static let minDayOfWeekSessions = 4
    static let dayOfWeekDominance = 0.4
    static let minVolumeDelta = 0.2
    static let minStableWeekCount = 2
    static let minActiveDaysDelta = 2
    static let minStreakDays = 3
    static let minGoalHitsDelta = 2
}

// MARK: - Detectors

private extension InsightGenerator {
    static func detectTimeOfDayMode(
        sessions: [Session]
    ) -> Insight? {
        guard sessions.count >= minTimeOfDaySessions else { return nil }
        let calendar = Calendar.current
        let buckets = Dictionary(grouping: sessions) { session in
            TimeOfDayBucket.bucket(
                for: calendar.component(.hour, from: session.startedAt)
            )
        }
        guard let entry = buckets.max(by: { $0.value.count < $1.value.count }) else {
            return nil
        }
        let ratio = Double(entry.value.count) / Double(sessions.count)
        guard ratio >= timeOfDayDominance else { return nil }
        return .timeOfDayMode(
            bucket: entry.key,
            ratio: ratio,
            sessionCount: entry.value.count
        )
    }

    static func detectDayOfWeekMode(
        sessions: [Session]
    ) -> Insight? {
        guard sessions.count >= minDayOfWeekSessions else { return nil }
        let calendar = Calendar.current
        let buckets = Dictionary(grouping: sessions) { session in
            calendar.component(.weekday, from: session.startedAt)
        }
        guard let entry = buckets.max(by: { $0.value.count < $1.value.count }) else {
            return nil
        }
        let ratio = Double(entry.value.count) / Double(sessions.count)
        guard ratio >= dayOfWeekDominance else { return nil }
        return .dayOfWeekMode(
            weekday: entry.key,
            ratio: ratio,
            sessionCount: entry.value.count
        )
    }

    static func detectVolumeChange(
        metric: Metric,
        current: [Session],
        previous: [Session]
    ) -> Insight? {
        guard current.count >= minStableWeekCount,
              previous.count >= minStableWeekCount
        else {
            return nil
        }
        let currentTotal = current.reduce(0.0) { $0 + $1.trackingValue }
        let previousTotal = previous.reduce(0.0) { $0 + $1.trackingValue }
        guard previousTotal > 0 else { return nil }
        let delta = abs(currentTotal - previousTotal) / previousTotal
        guard delta >= minVolumeDelta else { return nil }
        return .volumeChange(
            measurementType: metric.measurementType,
            unit: metric.unit,
            currentTotal: currentTotal,
            previousTotal: previousTotal,
            currentCount: current.count,
            previousCount: previous.count
        )
    }

    static func detectActiveDaysChange(
        current: [Session],
        previous: [Session]
    ) -> Insight? {
        let currentDays = activeDays(in: current)
        let previousDays = activeDays(in: previous)
        guard currentDays > 0, previousDays > 0 else { return nil }
        guard abs(currentDays - previousDays) >= minActiveDaysDelta else { return nil }
        return .activeDaysChange(
            currentDays: currentDays,
            previousDays: previousDays
        )
    }

    static func detectStreak(
        metric: Metric,
        sessions: [Session]
    ) -> Insight? {
        let totals = SessionStatistics.dailyTotals(from: sessions)
        let streak = SessionStatistics.currentStreak(
            from: totals, excludedWeekdays: metric.excludedWeekdaySet
        )
        guard streak >= minStreakDays else { return nil }
        return .currentStreak(days: streak)
    }

    static func detectGoalHitRateChange(
        metric: Metric,
        current: [Session],
        previous: [Session]
    ) -> Insight? {
        guard let goal = metric.dailyGoal else { return nil }
        let currentHits = goalHits(in: current, goal: goal)
        let previousHits = goalHits(in: previous, goal: goal)
        guard abs(currentHits - previousHits) >= minGoalHitsDelta else { return nil }
        return .goalHitRateChange(
            currentHits: currentHits,
            previousHits: previousHits
        )
    }

    static func activeDays(in sessions: [Session]) -> Int {
        let calendar = Calendar.current
        return Set(sessions.map { calendar.startOfDay(for: $0.startedAt) }).count
    }

    static func goalHits(in sessions: [Session], goal: TimeInterval) -> Int {
        let totals = SessionStatistics.dailyTotals(from: sessions)
        return totals.filter { $0.duration >= goal }.count
    }
}
