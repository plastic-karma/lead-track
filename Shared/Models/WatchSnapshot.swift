import Foundation

/// A lightweight, codable mirror of one metric for the watch app. The watch
/// never opens the SwiftData store; it renders these snapshots and sends
/// recording actions back to the phone.
struct WatchMetricSnapshot: Codable, Equatable, Identifiable {
    let id: UUID
    let name: String
    /// The raw `MeasurementType` as it traveled over the wire. Kept raw —
    /// like every field added after the first release — so a snapshot from a
    /// newer phone with an unknown type still decodes: that one metric
    /// degrades to a read-only row instead of failing the whole snapshot.
    /// Encodes under the original `measurementType` key.
    var measurementTypeRaw: String
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
    /// When a binary habit's show-up expectation was released (mirrors
    /// `Metric.binaryGoalRetiredAt`). Optional so snapshots cached by earlier
    /// app versions still decode; nil reads as "expected", the old
    /// behavior.
    var binaryGoalRetiredAt: Date?
    /// Raw `CountLogStyle` deciding what tapping a count row does (mirrors
    /// `Metric.countLogStyleRaw`). Optional so snapshots cached by earlier
    /// app versions still decode; nil reads as asking for the amount, the
    /// old behavior.
    var countLogStyleRaw: String?

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case measurementTypeRaw = "measurementType"
        case unit
        case icon
        case colorName
        case runningSince
        case todayTotal
        case dailyGoal
        case excludedWeekdays
        case countdownDuration
        case healthSourceRaw
        case binaryGoalRetiredAt
        case countLogStyleRaw
    }

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
        healthSourceRaw: String? = nil,
        binaryGoalRetiredAt: Date? = nil,
        countLogStyleRaw: String? = nil
    ) {
        self.id = id
        self.name = name
        measurementTypeRaw = measurementType.rawValue
        self.unit = unit
        self.icon = icon
        self.colorName = colorName
        self.runningSince = runningSince
        self.todayTotal = todayTotal
        self.dailyGoal = dailyGoal
        self.excludedWeekdays = excludedWeekdays
        self.countdownDuration = countdownDuration
        self.healthSourceRaw = healthSourceRaw
        self.binaryGoalRetiredAt = binaryGoalRetiredAt
        self.countLogStyleRaw = countLogStyleRaw
    }
}

extension WatchMetricSnapshot {
    /// The decoded measurement type, or nil when the snapshot came from a
    /// newer app version whose type this build doesn't know — consumers
    /// render such a metric read-only.
    var measurementType: MeasurementType? {
        MeasurementType(rawValue: measurementTypeRaw)
    }

    /// The SF Symbol the watch surfaces show: the metric's own icon, else
    /// the shared type-aware fallback; an unknown type reads as a dashed
    /// circle.
    var displayIcon: String {
        icon ?? measurementType?.fallbackIcon ?? "circle.dashed"
    }

    /// The range a running countdown animates across, or nil when the metric
    /// isn't running or counts up.
    var countdownInterval: ClosedRange<Date>? {
        guard let since = runningSince else { return nil }
        return CountdownDisplay.interval(startedAt: since, duration: countdownDuration)
    }

    /// Whether the phone fills this metric from Apple Health. The watch
    /// renders it read-only: health data is recorded by sensors, not taps.
    var isHealthLinked: Bool {
        healthSourceRaw != nil
    }

    /// What tapping a count row does, mirroring `Metric.countLogStyle`.
    /// nil (snapshots from older phones) and unknown raw values read as
    /// asking for the amount.
    var countLogStyle: CountLogStyle {
        countLogStyleRaw.flatMap(CountLogStyle.init(rawValue:)) ?? .askAmount
    }

    /// The shared daily-target rule over the snapshot's raw fields.
    var hasDailyTarget: Bool {
        DailyTargetRule.exists(
            measurementType: measurementType,
            binaryGoalRetiredAt: binaryGoalRetiredAt,
            dailyGoal: dailyGoal
        )
    }

    /// Whether the daily goal applies on the given date's weekday.
    func isGoalDay(on date: Date, calendar: Calendar = .current) -> Bool {
        GoalDayRule.isGoalDay(
            on: date,
            excludedWeekdays: excludedWeekdays ?? [],
            calendar: calendar
        )
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
    /// When the phone built this snapshot. The watch ignores payloads older
    /// than the one it holds, so a stale application-context replay on
    /// activation (or a delayed reply racing a newer push) can no longer
    /// roll back optimistic state. nil in payloads from app versions that
    /// predate the field; those are always accepted, the old behavior.
    var builtAt: Date?

    init(metrics: [WatchMetricSnapshot], day: Date? = nil, builtAt: Date? = nil) {
        self.metrics = metrics
        self.day = day
        self.builtAt = builtAt
    }

    static let empty = WatchSnapshot(metrics: [])
}

extension WatchSnapshot {
    /// Whether two snapshots carry the same content, ignoring when they were
    /// built — the phone's dedup for skipping no-op context pushes.
    func hasSameContent(as other: WatchSnapshot) -> Bool {
        metrics == other.metrics && day == other.day
    }
}
