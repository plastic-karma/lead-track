import Foundation

enum InsightCategory: Hashable {
    case volume, distribution, consistency, goal
    /// The measure's grip on behavior (see `MeasureHealth`): copy questions
    /// the measure, never the user.
    case measureHealth
}

enum TimeOfDayBucket: String, Equatable, CaseIterable {
    case morning, afternoon, evening, night

    static func bucket(for hour: Int) -> TimeOfDayBucket {
        switch hour {
        case 5 ..< 12: .morning
        case 12 ..< 17: .afternoon
        case 17 ..< 21: .evening
        default: .night
        }
    }

    var label: String {
        switch self {
        case .morning: "morning"
        case .afternoon: "afternoon"
        case .evening: "evening"
        case .night: "night"
        }
    }

    var symbol: String {
        switch self {
        case .morning: "sunrise"
        case .afternoon: "sun.max"
        case .evening: "sunset"
        case .night: "moon.stars"
        }
    }
}

/// One detected pattern in a single metric's week. Insights are always shown
/// inside that metric's own context (its weekly review card), so the copy
/// never repeats the metric name.
enum Insight: Equatable {
    case timeOfDayMode(
        bucket: TimeOfDayBucket,
        ratio: Double,
        sessionCount: Int
    )
    case dayOfWeekMode(
        weekday: Int,
        ratio: Double,
        sessionCount: Int
    )
    case volumeChange(
        measurementType: MeasurementType,
        unit: String?,
        currentTotal: Double,
        previousTotal: Double,
        currentCount: Int,
        previousCount: Int
    )
    case activeDaysChange(
        currentDays: Int,
        previousDays: Int
    )
    case goalHitRateChange(
        currentHits: Int,
        previousHits: Int
    )
    /// Daily totals hugging the goal line — is the line the point?
    case goalClustering(
        bandedHits: Int,
        totalHits: Int
    )
    /// Tiny late sole-session days under a long streak — the chain being fed.
    case streakSaver(
        occurrences: Int,
        streak: Int
    )
}

extension Insight {
    var category: InsightCategory {
        switch self {
        case .timeOfDayMode, .dayOfWeekMode: .distribution
        case .volumeChange: .volume
        case .activeDaysChange: .consistency
        case .goalHitRateChange: .goal
        case .goalClustering, .streakSaver: .measureHealth
        }
    }

    var symbol: String {
        switch self {
        case let .timeOfDayMode(bucket, _, _):
            bucket.symbol
        case .dayOfWeekMode:
            "calendar"
        case let .volumeChange(_, _, current, previous, _, _):
            current >= previous
                ? "chart.line.uptrend.xyaxis"
                : "chart.line.downtrend.xyaxis"
        case let .activeDaysChange(current, previous):
            current >= previous
                ? "calendar.badge.checkmark"
                : "calendar.badge.exclamationmark"
        case .goalHitRateChange:
            "target"
        case .goalClustering:
            "ruler"
        case .streakSaver:
            "link"
        }
    }
}

extension Insight {
    var headline: String {
        switch self {
        case let .timeOfDayMode(bucket, _, _):
            "Mostly a \(bucket.label) thing"
        case let .dayOfWeekMode(weekday, _, _):
            "Mostly a \(Self.weekdayName(weekday)) thing"
        case let .volumeChange(_, _, current, previous, _, _):
            current >= previous ? "Up this week" : "Down this week"
        case let .activeDaysChange(current, previous):
            current >= previous ? "Active on more days" : "Active on fewer days"
        case let .goalHitRateChange(current, previous):
            current >= previous
                ? "Hitting the goal more often"
                : "Hitting the goal less often"
        case .goalClustering:
            "Days often stop right at the goal"
        case .streakSaver:
            "Small late saves kept the chain"
        }
    }

    var detail: String {
        switch self {
        case let .timeOfDayMode(_, ratio, count):
            return Self.percentageDetail(ratio: ratio, count: count, suffix: "in that window")
        case let .dayOfWeekMode(_, ratio, count):
            return Self.percentageDetail(ratio: ratio, count: count, suffix: "on that day")
        case let .volumeChange(type, unit, currentTotal, previousTotal, currentCount, previousCount):
            return Self.volumeDetail(
                type: type, unit: unit,
                current: VolumeSnapshot(total: currentTotal, sessions: currentCount),
                previous: VolumeSnapshot(total: previousTotal, sessions: previousCount)
            )
        case let .activeDaysChange(current, previous):
            return "\(current)/7 days vs \(previous)/7 last week"
        case let .goalHitRateChange(current, previous):
            return "Hit goal \(current)/7 days vs \(previous)/7"
        case let .goalClustering(banded, hits):
            return "\(banded) of \(hits) goal days landed within "
                + "\(Int(MeasureHealth.clusterBand * 100))% of the line. Is the goal "
                + "the right size — or has the line become the point?"
        case let .streakSaver(occurrences, _):
            return "\(occurrences) evenings these past "
                + "\(MeasureHealth.lookbackDays / 7) weeks, a session at most "
                + "\(Int(MeasureHealth.saverValueShare * 100))% of your usual "
                + "size landed after \(Self.hourLabel(MeasureHealth.saverLateHour)). "
                + "Would a rest day serve the why better than the chain?"
        }
    }
}

private extension Insight {
    struct VolumeSnapshot: Equatable {
        let total: Double
        let sessions: Int
        var average: Double {
            sessions >= 1 ? total / Double(sessions) : 0
        }
    }

    enum VolumeFactor {
        case count, length, both
    }

    static let factorDominanceMultiple = 1.5

    static func percentageDetail(
        ratio: Double,
        count: Int,
        suffix: String
    ) -> String {
        let percent = Int((ratio * 100).rounded())
        return "\(percent)% of sessions (\(count)) \(suffix)"
    }

    static func weekdayName(_ weekday: Int) -> String {
        let symbols = Calendar.current.standaloneWeekdaySymbols
        let index = max(0, min(weekday - 1, symbols.count - 1))
        return symbols[index]
    }

    /// "9 pm"-style label for an hour-of-day threshold, so the copy tracks
    /// the detector constant it describes (`MeasureHealth.saverLateHour`).
    static func hourLabel(_ hour: Int) -> String {
        hour > 12 ? "\(hour - 12) pm" : "\(hour) am"
    }

    static func volumeDetail(
        type: MeasurementType,
        unit: String?,
        current: VolumeSnapshot,
        previous: VolumeSnapshot
    ) -> String {
        switch dominantFactor(current: current, previous: previous) {
        case .count:
            return "\(current.sessions) sessions vs \(previous.sessions) last week"
        case .length:
            let cur = ValueFormatter.format(current.average, type: type, unit: unit)
            let prev = ValueFormatter.format(previous.average, type: type, unit: unit)
            return "Avg \(cur) vs \(prev) last week"
        case .both:
            let cur = ValueFormatter.format(current.total, type: type, unit: unit)
            let prev = ValueFormatter.format(previous.total, type: type, unit: unit)
            return "\(cur) vs \(prev) last week"
        }
    }

    static func dominantFactor(
        current: VolumeSnapshot,
        previous: VolumeSnapshot
    ) -> VolumeFactor {
        guard previous.sessions >= 1, current.sessions >= 1,
              previous.average > 0, previous.total > 0
        else {
            return .both
        }
        let countDelta = abs(
            Double(current.sessions - previous.sessions) / Double(previous.sessions)
        )
        let lengthDelta = abs(current.average - previous.average) / previous.average
        if countDelta > lengthDelta * factorDominanceMultiple { return .count }
        if lengthDelta > countDelta * factorDominanceMultiple { return .length }
        return .both
    }
}
