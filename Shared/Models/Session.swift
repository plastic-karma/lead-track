import Foundation
import SwiftData

@Model
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
