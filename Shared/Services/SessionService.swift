#if canImport(ActivityKit)
import ActivityKit
#endif
import Foundation
import SwiftData

enum SessionService {
    static func activeSession(for metric: Metric) -> Session? {
        metric.sessions.first { $0.isRunning }
    }

    @discardableResult
    static func startSession(
        for metric: Metric,
        project: Project? = nil,
        in context: ModelContext
    ) -> Session {
        if let running = activeSession(for: metric) {
            return running
        }
        let session = Session(
            metric: metric,
            project: project,
            startedAt: .now
        )
        context.insert(session)
        startLiveActivity(
            metric: metric,
            project: project,
            startedAt: session.startedAt
        )
        return session
    }

    static func stopSession(_ session: Session) {
        session.endedAt = .now
        stopLiveActivity()
        if let metric = session.metric {
            rescheduleNotifications(for: metric)
        }
    }

    @discardableResult
    static func logCount(
        _ value: Double,
        for metric: Metric,
        project: Project? = nil,
        in context: ModelContext
    ) -> Session {
        let session = Session(
            metric: metric,
            project: project,
            startedAt: .now,
            endedAt: .now,
            value: value
        )
        context.insert(session)
        rescheduleNotifications(for: metric)
        return session
    }

    static func stopSession(for metric: Metric) {
        guard let running = activeSession(for: metric) else { return }
        running.endedAt = .now
        stopLiveActivity()
        rescheduleNotifications(for: metric)
    }

    private static func rescheduleNotifications(
        for metric: Metric
    ) {
        #if canImport(UserNotifications)
        NotificationService.rescheduleMetric(metric)
        #endif
    }

    // MARK: - Live Activity

    private static func startLiveActivity(
        metric: Metric,
        project: Project?,
        startedAt: Date
    ) {
        #if canImport(ActivityKit)
        let attributes = TimerActivityAttributes(
            metricName: metric.name,
            projectName: project?.name,
            icon: metric.icon ?? "clock"
        )
        let state = TimerActivityAttributes.ContentState(
            startedAt: startedAt
        )
        let content = ActivityContent(
            state: state,
            staleDate: nil
        )
        _ = try? Activity.request(
            attributes: attributes,
            content: content,
            pushType: nil
        )
        #endif
    }

    private static func stopLiveActivity() {
        #if canImport(ActivityKit)
        Task {
            for activity in Activity<TimerActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
        #endif
    }
}
