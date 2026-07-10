import Foundation
#if canImport(SwiftData)
import SwiftData
#endif

#if canImport(SwiftData)
@Model
#endif
final class Metric {
    #if canImport(SwiftData)
    #Unique<Metric>([\.stableID])
    #endif
    var stableID: UUID?
    var name: String
    var metricDescription: String?
    /// Stored as the enum itself — a pre-doctrine exception. Every enum
    /// attribute added since is stored raw (`xxxRaw: String` + typed
    /// accessor) so a store written by a newer app version still opens;
    /// adding a MeasurementType case therefore requires migrating this
    /// field to that pattern first. Do not copy this shape for new fields.
    var measurementType: MeasurementType
    var unit: String?
    var icon: String?
    var colorName: String?
    var createdAt: Date
    var dailyGoal: TimeInterval?
    var weeklyGoal: TimeInterval?
    var reminderTime: Date?
    var streakAlertTime: Date?
    /// Fixed daily-reminder times (up to `ReminderSchedule.maxPerDay`). When
    /// non-empty these are the reminder's fire times; when empty the legacy
    /// single `reminderTime` stands in. Defaults empty, so existing stores
    /// migrate untouched.
    var reminderTimes: [Date] = []
    /// Random-mode window (times of day). With `reminderUsesRandom` on and both
    /// bounds set, the reminder fires `reminderRandomCount` times at random
    /// moments inside the window each goal day. Default nil, so existing stores
    /// migrate untouched.
    var reminderRandomStart: Date?
    var reminderRandomEnd: Date?
    /// Random-mode ping count (1...`ReminderSchedule.maxPerDay`). Defaulted, so
    /// existing stores migrate untouched.
    var reminderRandomCount: Int = 2
    /// Whether the reminder uses the random window rather than fixed times.
    /// Default false, so existing stores keep their single fixed reminder.
    var reminderUsesRandom: Bool = false
    var excludedWeekdays: [Int] = []
    /// Raw `HealthDataSource` this metric mirrors, or nil for a hand-recorded
    /// metric. Stored as the raw string (not the enum) so a store written by a
    /// newer app version with an unknown source still opens. Optional and
    /// defaulting to nil, so existing stores migrate untouched.
    var healthSourceRaw: String?
    /// When the mirror last finished refreshing this metric from HealthKit.
    var lastHealthSyncAt: Date?
    /// Raw `HealthExportTarget` this metric's sessions are written back to
    /// Apple Health as, or nil when nothing is sent. Stored as the raw string
    /// (not the enum) for the same forward-compatibility reason as
    /// `healthSourceRaw`. Optional and defaulting to nil, so existing stores
    /// migrate untouched.
    var healthExportRaw: String?
    /// When export was switched on. Only sessions started at or after this
    /// are written, so enabling never floods Health with months of history.
    var healthExportEnabledAt: Date?
    /// When the current goal season began: stamped when a goal is enabled,
    /// an amount changes, or the season is renewed at a review (see
    /// `GoalSeason`). nil = an unseasoned pre-feature goal, which is never
    /// due. Optional and defaulting to nil, so existing stores migrate
    /// untouched.
    var goalSeasonStartedAt: Date?
    /// The season's length in weeks, chosen when the goal is set
    /// (`GoalSeason.lengthChoices`). nil alongside a goal = unseasoned.
    var goalSeasonWeeks: Int?
    /// What this season is for, in the user's words — the review row's
    /// framing line. Defaults empty, so existing metrics migrate untouched.
    var goalSeasonNote: String = ""
    /// When a binary habit's implicit "do it today" expectation was released
    /// (retired at a season review or switched off in goal settings). nil —
    /// the default, so existing stores migrate untouched — means the
    /// expectation is live. Meaningless on quantity metrics, whose pressure
    /// lives in amount goals.
    var binaryGoalRetiredAt: Date?
    /// Raw `CountLogStyle` deciding what a count metric's primary log action
    /// does. Stored as the raw string (not the enum) for the same
    /// forward-compatibility reason as `healthSourceRaw`. Defaults to asking
    /// for the amount — the behavior before the setting existed — so existing
    /// stores migrate untouched. Meaningless on non-count metrics.
    var countLogStyleRaw: String = CountLogStyle.askAmount.rawValue
    /// When the metric was archived — set it aside without deleting its
    /// history. Archived metrics leave the day and week surfaces (Today,
    /// Week, watch, widgets, reminders) until unarchived. nil — the default,
    /// so existing stores migrate untouched — means the metric is live.
    var archivedAt: Date?

    #if canImport(SwiftData)
    @Relationship(deleteRule: .cascade, inverse: \Project.metric)
    #endif
    var projects: [Project] = []

    #if canImport(SwiftData)
    @Relationship(deleteRule: .cascade, inverse: \Session.metric)
    #endif
    var sessions: [Session] = []

    // Back-array for the many-to-many with `Aspiration`. Plain (no macro): the
    // `inverse:` is declared on `Aspiration` only. Defaults empty, so every
    // existing metric reads as "no aspirations" with no migration.
    var aspirations: [Aspiration] = []

    /// Back-array for the derived intentions computing from this metric.
    /// Plain (no macro): the `inverse:` lives on `Intention.metric`, and both
    /// sides nullify — deleting a metric strands its intentions ("source
    /// removed") rather than deleting them. Defaults empty, so existing
    /// metrics migrate untouched.
    var intentions: [Intention] = []

    /// Back-array for the moments logged here as provenance. Plain (no macro):
    /// the `inverse:` lives on `Moment.metric`, and both sides nullify —
    /// deleting a metric drops the link and the moment survives. Defaults
    /// empty, so existing metrics migrate untouched.
    var moments: [Moment] = []

    init(
        name: String,
        measurementType: MeasurementType = .duration,
        unit: String? = nil,
        icon: String? = nil,
        colorName: String? = nil,
        metricDescription: String? = nil,
        createdAt: Date = .now,
        healthSource: HealthDataSource? = nil
    ) {
        stableID = UUID()
        self.name = name
        self.metricDescription = metricDescription
        self.measurementType = measurementType
        self.unit = unit
        self.icon = icon
        self.colorName = colorName
        self.createdAt = createdAt
        healthSourceRaw = healthSource?.rawValue
    }
}

// MARK: - Health Link

extension Metric {
    /// The Apple Health figure this metric mirrors, or nil for a
    /// hand-recorded metric.
    var healthSource: HealthDataSource? {
        healthSourceRaw.flatMap(HealthDataSource.init(rawValue:))
    }

    /// Whether sessions are filled from Apple Health instead of recorded by
    /// hand. True even when the stored source string is unknown to this app
    /// version, so manual logging never contaminates a mirrored metric.
    /// Every recording surface — cards, detail, watch actions, widgets,
    /// intents, CSV import — checks this before writing a session.
    var isHealthLinked: Bool {
        healthSourceRaw != nil
    }
}

// MARK: - Health Export

extension Metric {
    /// The Apple Health record this metric's sessions are written back as,
    /// or nil when nothing is sent.
    var healthExportTarget: HealthExportTarget? {
        healthExportRaw.flatMap(HealthExportTarget.init(rawValue:))
    }

    /// Whether this metric can send sessions to Apple Health at all: only
    /// timer metrics record intervals Health can represent, and mirrored
    /// metrics must never write back what was read from Health.
    var supportsHealthExport: Bool {
        measurementType == .duration && !isHealthLinked
    }

    /// Switches export on, off, or to another target, keeping
    /// `healthExportEnabledAt` meaningful: turning on stamps `date`, changing
    /// the target keeps the original stamp, and turning off clears it.
    func setHealthExport(_ target: HealthExportTarget?, at date: Date = .now) {
        guard let target else {
            healthExportRaw = nil
            healthExportEnabledAt = nil
            return
        }
        if healthExportEnabledAt == nil {
            healthExportEnabledAt = date
        }
        healthExportRaw = target.rawValue
    }
}

// MARK: - Count Logging

extension Metric {
    /// What the primary log action does on a count metric: ask how many to
    /// add, or add a single unit on the spot. A stored value this app
    /// version doesn't know (written by a newer one) reads as asking, the
    /// safe interpretation.
    var countLogStyle: CountLogStyle {
        get { CountLogStyle(rawValue: countLogStyleRaw) ?? .askAmount }
        set { countLogStyleRaw = newValue.rawValue }
    }

    /// Whether the primary count action logs one unit without asking.
    var logsOneUnitImmediately: Bool {
        countLogStyle == .incrementByOne
    }
}

// MARK: - Default Project

extension Metric {
    /// The active project that new recordings are auto-assigned to, if any.
    /// At most one active project per metric can be the default.
    var defaultProject: Project? {
        projects.first { $0.isDefault && $0.status == .active }
    }
}

// MARK: - Display Icon

extension Metric {
    /// The SF Symbol every surface shows for the metric, with the shared
    /// type-aware fallback for metrics saved before icons existed.
    var displayIcon: String {
        icon ?? measurementType.fallbackIcon
    }
}

// MARK: - Description

extension Metric {
    /// Normalizes free-text description input: trims surrounding whitespace and
    /// collapses an all-whitespace string to nil, so a blank description is
    /// stored as "no description" rather than an empty string.
    static func normalizedDescription(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

// MARK: - Lookup

#if canImport(SwiftData)
extension Metric {
    /// Fetches the metric carrying this stable identity — the ID that watch
    /// actions, widget configurations, and intents reference.
    static func find(
        stableID id: UUID,
        in context: ModelContext
    ) throws -> Metric? {
        var descriptor = FetchDescriptor<Metric>(
            predicate: #Predicate { $0.stableID == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}
#endif

// MARK: - Archive

extension Metric {
    /// Whether the metric is set aside: hidden from the day and week
    /// surfaces while keeping every session, goal, and link for the day it
    /// returns.
    var isArchived: Bool {
        archivedAt != nil
    }

    /// Sets the metric aside, stamping when. Side effects — stopping a
    /// running timer, cancelling reminders, refreshing the watch — stay with
    /// the callers, which live behind Apple-only frameworks.
    func archive(at date: Date = .now) {
        archivedAt = date
    }

    /// Brings the metric back to the day and week surfaces.
    func unarchive() {
        archivedAt = nil
    }
}

extension Array where Element == Metric {
    /// The metrics still living on the day and week surfaces — everything
    /// not archived, in their incoming order.
    var unarchived: [Metric] {
        filter { !$0.isArchived }
    }
}

// MARK: - Daily Show-Up Expectation

extension Metric {
    /// Whether the binary habit still carries its implicit "do it today"
    /// target — true until the expectation is retired. A released habit
    /// keeps its card, logging, and streak history, but drops out of the
    /// day's rings and done/left arithmetic, exactly as a quantity metric
    /// behaves after its amount goal retires.
    var expectsDailyShowUp: Bool {
        measurementType == .binary && binaryGoalRetiredAt == nil
    }
}

// MARK: - Daily Goal Schedule

extension Metric {
    /// Weekday numbers (1 = Sunday ... 7 = Saturday) excluded from the daily goal.
    var excludedWeekdaySet: Set<Int> {
        Set(excludedWeekdays)
    }

    /// Whether the daily goal applies on the given date's weekday.
    func isGoalDay(on date: Date, calendar: Calendar = .current) -> Bool {
        !excludedWeekdays.contains(calendar.component(.weekday, from: date))
    }
}
