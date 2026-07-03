import Foundation

/// A lightweight, codable mirror of one metric for the watch app. The watch
/// never opens the SwiftData store; it renders these snapshots and sends
/// recording actions back to the phone.
struct WatchMetricSnapshot: Codable, Equatable, Identifiable {
    let id: UUID
    let name: String
    let measurementType: MeasurementType
    let unit: String?
    let icon: String?
    let colorName: String?
    var runningSince: Date?
    var todayTotal: Double
    /// The daily target in the metric's native unit — seconds for duration
    /// metrics, a raw count otherwise. nil when no amount goal is set;
    /// binary metrics stay nil because their implicit "do it today" target
    /// follows from `measurementType`. Optional so snapshots cached by
    /// earlier app versions still decode.
    var dailyGoal: Double?
    /// Weekday numbers (1 = Sunday ... 7 = Saturday) the daily goal skips.
    /// Optional for the same decode-compatibility reason; nil reads as
    /// "no rest days".
    var excludedWeekdays: [Int]?
    /// Seconds a countdown timer runs for, or nil when the metric counts up.
    var countdownDuration: TimeInterval?
    /// Raw `HealthDataSource` for a metric mirrored from Apple Health, nil
    /// for a hand-recorded one. Optional so snapshots cached by earlier app
    /// versions still decode.
    var healthSourceRaw: String?

    init(
        id: UUID,
        name: String,
        measurementType: MeasurementType,
        unit: String?,
        icon: String?,
        colorName: String?,
        runningSince: Date? = nil,
        todayTotal: Double = 0,
        dailyGoal: Double? = nil,
        excludedWeekdays: [Int]? = nil,
        countdownDuration: TimeInterval? = nil,
        healthSourceRaw: String? = nil
    ) {
        self.id = id
        self.name = name
        self.measurementType = measurementType
        self.unit = unit
        self.icon = icon
        self.colorName = colorName
        self.runningSince = runningSince
        self.todayTotal = todayTotal
        self.dailyGoal = dailyGoal
        self.excludedWeekdays = excludedWeekdays
        self.countdownDuration = countdownDuration
        self.healthSourceRaw = healthSourceRaw
    }
}

extension WatchMetricSnapshot {
    /// The range a running countdown animates across, or nil when the metric
    /// isn't running or counts up.
    var countdownInterval: ClosedRange<Date>? {
        guard let since = runningSince, let target = countdownDuration, target > 0 else { return nil }
        return since ... since.addingTimeInterval(target)
    }

    /// Whether the phone fills this metric from Apple Health. The watch
    /// renders it read-only: health data is recorded by sensors, not taps.
    var isHealthLinked: Bool {
        healthSourceRaw != nil
    }

    /// Mirrors `GoalSummary`: binary metrics always carry an implicit
    /// "do it today" target; the others need an amount goal.
    var hasDailyTarget: Bool {
        measurementType == .binary || dailyGoal != nil
    }

    /// Whether the daily goal applies on the given date's weekday, mirroring
    /// `Metric.isGoalDay(on:calendar:)` over the shipped weekday set.
    func isGoalDay(on date: Date, calendar: Calendar = .current) -> Bool {
        !(excludedWeekdays ?? []).contains(calendar.component(.weekday, from: date))
    }
}

/// Everything the watch needs to render its UI, pushed from the phone over
/// WatchConnectivity and cached on the watch for offline launches.
struct WatchSnapshot: Codable, Equatable {
    var metrics: [WatchMetricSnapshot]
    /// Start of the (phone-local) day the metrics' `todayTotal`s describe,
    /// so consumers can zero totals that have gone stale overnight. nil in
    /// caches written before this field existed; those totals are trusted
    /// as current, preserving the old behavior.
    var day: Date?

    init(metrics: [WatchMetricSnapshot], day: Date? = nil) {
        self.metrics = metrics
        self.day = day
    }

    static let empty = WatchSnapshot(metrics: [])
}
