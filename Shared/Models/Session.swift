import Foundation
#if canImport(SwiftData)
import SwiftData
#endif

#if canImport(SwiftData)
@Model
#endif
final class Session {
    var metric: Metric?
    var project: Project?
    var startedAt: Date
    var endedAt: Date?
    var value: Double?
    /// When set on a running timer, the readout counts down from this many
    /// seconds instead of up — chosen per session when the user starts a
    /// countdown. Display-only: the recorded length is still real elapsed time.
    var countdownDuration: TimeInterval?
    /// When this session was written to Apple Health (see
    /// `HealthSessionExport`); nil means not sent, so each session is
    /// exported at most once. Optional and defaulting to nil, so existing
    /// stores migrate untouched.
    var healthExportedAt: Date?

    var isRunning: Bool {
        endedAt == nil && value == nil
    }

    var duration: TimeInterval {
        let end = endedAt ?? .now
        return end.timeIntervalSince(startedAt)
    }

    var trackingValue: Double {
        value ?? duration
    }

    init(
        metric: Metric? = nil,
        project: Project? = nil,
        startedAt: Date = .now,
        endedAt: Date? = nil,
        value: Double? = nil,
        countdownDuration: TimeInterval? = nil
    ) {
        self.metric = metric
        self.project = project
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.value = value
        self.countdownDuration = countdownDuration
    }
}

extension Session {
    /// Where a live timer display should count from so it shows the whole
    /// day, not just this session: the start, backdated by the day's
    /// already-completed total.
    func liveTimerOrigin(backdatedBy completedTotal: TimeInterval) -> Date {
        startedAt.addingTimeInterval(-completedTotal)
    }

    /// Whether this session's timer counts down from a fixed target.
    var countsDown: Bool {
        (countdownDuration ?? 0) > 0
    }

    /// The range a running countdown animates across — start to the instant it
    /// reaches zero — or nil for a count-up session.
    var countdownInterval: ClosedRange<Date>? {
        CountdownDisplay.interval(startedAt: startedAt, duration: countdownDuration)
    }

    /// The one value-rendering rule for a completed session row, shared by
    /// the metric detail's History fold and the full session list one tap
    /// behind it: a binary metric's day reads "Done", a counted value
    /// formats with its unit, a timed session formats its duration.
    func displayValue(unit: String?) -> String {
        if metric?.measurementType == .binary { return "Done" }
        if let value {
            return ValueFormatter.format(value, type: .count, unit: unit)
        }
        return DurationFormatter.format(duration)
    }
}

#if canImport(SwiftData)
extension Session {
    /// The fetchable form of `isRunning`, so queries and `isRunning` can
    /// never drift apart.
    static let isRunningPredicate = #Predicate<Session> {
        $0.endedAt == nil && $0.value == nil
    }
}
#endif
