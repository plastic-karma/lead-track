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
        value: Double? = nil
    ) {
        self.metric = metric
        self.project = project
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.value = value
    }
}

extension Session {
    /// Where a live timer display should count from so it shows the whole
    /// day, not just this session: the start, backdated by the day's
    /// already-completed total.
    func liveTimerOrigin(backdatedBy completedTotal: TimeInterval) -> Date {
        startedAt.addingTimeInterval(-completedTotal)
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
