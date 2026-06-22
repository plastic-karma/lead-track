#if canImport(ActivityKit)
import ActivityKit
#endif
import Foundation
import SwiftData

enum SessionService {
    static func activeSession(for metric: Metric) -> Session? {
        metric.sessions.first { $0.isRunning }
    }

    /// Starts the metric's timer, or stops the one already running — the
    /// single toggle behind every start/stop button.
    static func toggleSession(
        for metric: Metric,
        in context: ModelContext
    ) {
        if let running = activeSession(for: metric) {
            stopSession(running)
        } else {
            startSession(for: metric, in: context)
        }
    }

    /// `at` records when the session actually began (clamped to now), so
    /// actions queued offline — e.g. from the watch — are backdated.
    @discardableResult
    static func startSession(
        for metric: Metric,
        project: Project? = nil,
        in context: ModelContext,
        at timestamp: Date = .now
    ) -> Session {
        if let running = activeSession(for: metric) {
            return running
        }
        let project = project ?? metric.defaultProject
        let session = Session(
            metric: metric,
            project: project,
            startedAt: min(timestamp, .now)
        )
        context.insert(session)
        startLiveActivity(
            metric: metric,
            project: project,
            startedAt: session.startedAt
        )
        return session
    }

    /// Reassigns a completed session to another project under the same metric,
    /// or to no project (top level) when `project` is nil. Returns false and
    /// makes no change if the target project belongs to a different metric.
    @discardableResult
    static func move(_ session: Session, to project: Project?) -> Bool {
        if let project, project.metric !== session.metric {
            return false
        }
        session.project = project
        return true
    }

    /// Ends the session at `timestamp`, clamped between its start and now.
    static func stopSession(_ session: Session, at timestamp: Date = .now) {
        session.endedAt = max(min(timestamp, .now), session.startedAt)
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
        in context: ModelContext,
        at timestamp: Date = .now
    ) -> Session {
        let project = project ?? metric.defaultProject
        let logged = min(timestamp, .now)
        let session = Session(
            metric: metric,
            project: project,
            startedAt: logged,
            endedAt: logged,
            value: value
        )
        context.insert(session)
        rescheduleNotifications(for: metric)
        return session
    }

    @discardableResult
    static func logDuration(
        _ duration: TimeInterval,
        startedAt: Date,
        for metric: Metric,
        project: Project? = nil,
        in context: ModelContext
    ) -> Session {
        let project = project ?? metric.defaultProject
        let session = Session(
            metric: metric,
            project: project,
            startedAt: startedAt,
            endedAt: startedAt.addingTimeInterval(duration)
        )
        context.insert(session)
        rescheduleNotifications(for: metric)
        return session
    }

    static func stopSession(for metric: Metric, at timestamp: Date = .now) {
        guard let running = activeSession(for: metric) else { return }
        stopSession(running, at: timestamp)
    }

    private static func rescheduleNotifications(
        for metric: Metric
    ) {
        #if canImport(UserNotifications)
        NotificationService.rescheduleMetric(metric)
        #endif
    }

    // MARK: - Live Activity

    /// Aligns the Live Activity with the store. Sessions started from the
    /// watch while the app was backgrounded can't show one immediately (the
    /// system only lets foreground apps start Live Activities), so the app
    /// calls this whenever it becomes active.
    static func syncLiveActivity(in context: ModelContext) {
        #if canImport(ActivityKit)
        let descriptor = FetchDescriptor<Session>(
            predicate: Session.isRunningPredicate
        )
        guard let running = try? context.fetch(descriptor).first,
              let metric = running.metric
        else {
            stopLiveActivity()
            return
        }
        guard Activity<TimerActivityAttributes>.activities.isEmpty
        else { return }
        startLiveActivity(
            metric: metric,
            project: running.project,
            startedAt: running.startedAt
        )
        #endif
    }

    private static func startLiveActivity(
        metric: Metric,
        project: Project?,
        startedAt: Date
    ) {
        #if canImport(ActivityKit)
        let attributes = TimerActivityAttributes(
            metricName: metric.name,
            projectName: project?.name,
            icon: metric.displayIcon,
            colorName: metric.colorName,
            countdownDuration: metric.countdownDuration
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
