#if canImport(ActivityKit) && !os(macOS)
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
    ///
    /// The caller passes the running session it resolved from its own
    /// `@Query`, which is the same source of truth that drew the button's
    /// label. Re-deriving it here from `metric.sessions` instead would risk
    /// disagreeing with the label: that relationship can lag a sibling
    /// context's save (e.g. an auto-stop), so a stale-running array would turn
    /// a "play" tap into a stop (timer never starts) and a stale-empty one
    /// would turn a "stop" tap into a start.
    static func toggleSession(
        for metric: Metric,
        runningSession: Session?,
        in context: ModelContext
    ) {
        if let runningSession {
            stopSession(runningSession)
        } else {
            startSession(for: metric, in: context)
        }
    }

    /// `at` records when the session actually began (clamped to now), so
    /// actions queued offline — e.g. from the watch — are backdated.
    /// `countdownDuration` (seconds) makes this one session count down instead
    /// of up; nil counts up. The choice is per-start, not a metric setting.
    @discardableResult
    static func startSession(
        for metric: Metric,
        project: Project? = nil,
        in context: ModelContext,
        at timestamp: Date = .now,
        countdownDuration: TimeInterval? = nil
    ) -> Session {
        if let running = storedRunningSession(for: metric, in: context) {
            return running
        }
        let project = project ?? metric.defaultProject
        let session = Session(
            metric: metric,
            project: project,
            startedAt: min(timestamp, .now),
            countdownDuration: countdownDuration
        )
        context.insert(session)
        startLiveActivity(
            metric: metric,
            project: project,
            session: session
        )
        scheduleCountdownCompletion(for: metric, session: session)
        return session
    }

    /// The metric's running session as the store sees it — the re-derivation
    /// `startSession` needs before inserting. `metric.sessions` can lag a
    /// sibling context's save (see `toggleSession`), and a phantom running
    /// entry there would make `startSession` hand it back and never start
    /// the timer, so this reads through `Session.isRunningPredicate` the way
    /// `reconcileCountdowns` and `nextCountdownEnd` already do.
    private static func storedRunningSession(
        for metric: Metric,
        in context: ModelContext
    ) -> Session? {
        let descriptor = FetchDescriptor<Session>(
            predicate: Session.isRunningPredicate
        )
        let running = (try? context.fetch(descriptor)) ?? []
        return running.first { $0.metric === metric }
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
        let endedAt = max(min(timestamp, .now), session.startedAt)
        session.endedAt = endedAt
        stopLiveActivity()
        if let metric = session.metric {
            cancelCountdownIfStoppedEarly(metric, session: session, endedAt: endedAt)
            rescheduleNotifications(for: metric)
        }
    }

    /// Stops every countdown timer whose target has already elapsed, recording
    /// it as ending at exactly its countdown length — so a countdown turns
    /// itself off even if the user never comes back to press stop. Returns
    /// whether anything changed, so callers can persist and refresh.
    @discardableResult
    static func reconcileCountdowns(
        in context: ModelContext,
        now: Date = .now
    ) -> Bool {
        let descriptor = FetchDescriptor<Session>(
            predicate: Session.isRunningPredicate
        )
        guard let running = try? context.fetch(descriptor) else { return false }
        var changed = false
        for session in running {
            guard let end = session.countdownInterval?.upperBound,
                  now >= end
            else { continue }
            stopSession(session, at: end)
            changed = true
        }
        return changed
    }

    /// The soonest instant a running countdown will reach zero, or nil if none
    /// is running — used to schedule the next auto-stop.
    static func nextCountdownEnd(in context: ModelContext) -> Date? {
        let descriptor = FetchDescriptor<Session>(
            predicate: Session.isRunningPredicate
        )
        guard let running = try? context.fetch(descriptor) else { return nil }
        return running
            .compactMap { $0.countdownInterval?.upperBound }
            .min()
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

    /// Marks today done for a binary metric, or clears it when the day was
    /// already done — the toggle behind the check-off button. Binary metrics
    /// keep at most one completed session per day; `at` lets watch actions
    /// backdate to when the user tapped. Returns the resulting done state.
    @discardableResult
    static func toggleBinaryDay(
        for metric: Metric,
        in context: ModelContext,
        at timestamp: Date = .now
    ) -> Bool {
        let logged = min(timestamp, .now)
        let calendar = Calendar.current
        let today = metric.sessions.filter {
            !$0.isRunning && calendar.isDate($0.startedAt, inSameDayAs: logged)
        }
        guard today.isEmpty else {
            for session in today {
                context.delete(session)
            }
            rescheduleNotifications(for: metric)
            return false
        }
        let session = Session(
            metric: metric,
            project: metric.defaultProject,
            startedAt: logged,
            endedAt: logged,
            value: 1
        )
        context.insert(session)
        rescheduleNotifications(for: metric)
        return true
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
        // Overlay builds compile this out: scheduling needs a real app
        // bundle, which the SwiftPM test process doesn't have.
        #if canImport(UserNotifications) && !LEADTRACK_OVERLAY
        NotificationService.rescheduleMetric(metric)
        #endif
    }

    /// Schedules the "time's up" alert for a countdown session; no-ops for a
    /// count-up session, whose `countdownInterval` is nil.
    private static func scheduleCountdownCompletion(
        for metric: Metric,
        session: Session
    ) {
        #if canImport(UserNotifications) && !LEADTRACK_OVERLAY
        guard let end = session.countdownInterval?.upperBound else { return }
        NotificationService.scheduleCountdownCompletion(for: metric, endsAt: end)
        #endif
    }

    /// Clears a pending countdown alert when the user stops before it fires;
    /// a countdown that runs to zero keeps its alert.
    private static func cancelCountdownIfStoppedEarly(
        _ metric: Metric,
        session: Session,
        endedAt: Date
    ) {
        #if canImport(UserNotifications) && !LEADTRACK_OVERLAY
        guard let end = session.countdownInterval?.upperBound,
              endedAt < end
        else { return }
        NotificationService.cancelCountdown(for: metric)
        #endif
    }

    // MARK: - Live Activity

    /// Aligns the Live Activity with the store. Sessions started from the
    /// watch while the app was backgrounded can't show one immediately (the
    /// system only lets foreground apps start Live Activities), so the app
    /// calls this whenever it becomes active.
    static func syncLiveActivity(in context: ModelContext) {
        #if canImport(ActivityKit) && !os(macOS)
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
            session: running
        )
        #endif
    }

    private static func startLiveActivity(
        metric: Metric,
        project: Project?,
        session: Session
    ) {
        #if canImport(ActivityKit) && !os(macOS)
        let attributes = TimerActivityAttributes(
            metricName: metric.name,
            projectName: project?.name,
            icon: metric.displayIcon,
            colorName: metric.colorName,
            countdownDuration: session.countdownDuration
        )
        let state = TimerActivityAttributes.ContentState(
            startedAt: session.startedAt
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
        #if canImport(ActivityKit) && !os(macOS)
        // End exactly the activities that exist now: the task runs later,
        // with no ordering guarantee, and must not sweep up an activity a
        // quick follow-up start created in the meantime.
        let activities = Activity<TimerActivityAttributes>.activities
        Task {
            for activity in activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
        #endif
    }
}
