import Foundation

/// One metric's goal state resolved for a specific instant: stale totals
/// zeroed, the rest day evaluated against that instant's weekday, and a
/// running timer credited only while its session started that same day
/// (sessions count toward the day they started).
struct ComplicationMetricProgress: Equatable, Identifiable {
    let id: UUID
    let name: String
    let icon: String
    let colorName: String?
    let measurementType: MeasurementType
    let unit: String?
    /// The staleness-corrected amount recorded today, never the raw cache
    /// value.
    let todayTotal: Double
    let dailyGoal: Double?
    let isRestDay: Bool
    let isRunning: Bool
}

extension ComplicationMetricProgress {
    /// Mirrors `GoalSummary`: binary metrics always carry an implicit
    /// "do it today" target; the others need an amount goal.
    var hasDailyTarget: Bool {
        measurementType == .binary || dailyGoal != nil
    }

    /// Whether the target counts right now — a rest day suspends it.
    var hasActiveTarget: Bool {
        hasDailyTarget && !isRestDay
    }

    /// Progress toward the daily target clamped to 0...1, or nil when no
    /// target applies right now. Binary metrics read 0 or 1.
    var fraction: Double? {
        guard hasActiveTarget else { return nil }
        if measurementType == .binary {
            return todayTotal > 0 ? 1 : 0
        }
        guard let goal = dailyGoal, goal > 0 else { return nil }
        return min(max(todayTotal / goal, 0), 1)
    }

    /// The whole-number percent complications print, truncated so 99.6%
    /// reads 99% (matching the phone's goal captions).
    var percent: Int? {
        fraction.map { Int($0 * 100) }
    }

    /// Whether today's target is met.
    var isMet: Bool {
        fraction.map { $0 >= 1 } ?? false
    }
}

/// Render-time math for the watch complications, resolving the cached
/// `WatchSnapshot` for an arbitrary instant so pre-rendered timeline entries
/// (including the one at next midnight) show the right numbers without a
/// phone push.
enum ComplicationProgress {
    /// Every snapshot metric resolved for the given instant, in snapshot
    /// (creation) order.
    static func metrics(
        in snapshot: WatchSnapshot,
        at now: Date = .now,
        calendar: Calendar = .current
    ) -> [ComplicationMetricProgress] {
        snapshot.metrics.map {
            progress(of: $0, day: snapshot.day, at: now, calendar: calendar)
        }
    }

    /// The Daily Goals complication's rows: metrics whose target applies
    /// that day, snapshot order, capped to what a small circle fits.
    static func goalLines(
        in snapshot: WatchSnapshot,
        at now: Date = .now,
        calendar: Calendar = .current,
        limit: Int = 3
    ) -> [ComplicationMetricProgress] {
        Array(
            metrics(in: snapshot, at: now, calendar: calendar)
                .filter(\.hasActiveTarget)
                .prefix(limit)
        )
    }

    /// Aggregate met/total across the instant's active targets — the Day
    /// Ring numbers. Agrees with `GoalSummary.daily(for:)` given a fresh
    /// snapshot.
    static func dailySummary(
        in snapshot: WatchSnapshot,
        at now: Date = .now,
        calendar: Calendar = .current
    ) -> GoalSummary {
        let active = metrics(in: snapshot, at: now, calendar: calendar)
            .filter(\.hasActiveTarget)
        return GoalSummary(
            met: active.filter(\.isMet).count,
            total: active.count
        )
    }

    private static func progress(
        of metric: WatchMetricSnapshot,
        day: Date?,
        at now: Date,
        calendar: Calendar
    ) -> ComplicationMetricProgress {
        ComplicationMetricProgress(
            id: metric.id,
            name: metric.name,
            icon: metric.icon ?? "clock",
            colorName: metric.colorName,
            measurementType: metric.measurementType,
            unit: metric.unit,
            todayTotal: effectiveTotal(of: metric, day: day, at: now, calendar: calendar),
            dailyGoal: metric.dailyGoal,
            isRestDay: !metric.isGoalDay(on: now, calendar: calendar),
            isRunning: metric.runningSince != nil
        )
    }

    /// The base total counts only while the snapshot's day is now's day
    /// (nil — a cache from an older app version — is trusted); a running
    /// timer adds its elapsed time only while it started in now's day,
    /// matching how sessions are credited to the day they started.
    private static func effectiveTotal(
        of metric: WatchMetricSnapshot,
        day: Date?,
        at now: Date,
        calendar: Calendar
    ) -> Double {
        var total = 0.0
        if day.map({ calendar.isDate($0, inSameDayAs: now) }) ?? true {
            total = metric.todayTotal
        }
        if let since = metric.runningSince, calendar.isDate(since, inSameDayAs: now) {
            total += max(now.timeIntervalSince(since), 0)
        }
        return total
    }
}
