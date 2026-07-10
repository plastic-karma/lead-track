import Foundation
import SwiftData

/// Builds the snapshot pushed to the watch from the SwiftData store.
enum WatchSnapshotBuilder {
    /// Today's and running sessions resolved up front, so assembling the
    /// snapshot doesn't fault every metric's full session history.
    private struct SessionIndex {
        var todayTotals: [UUID: Double]
        var running: [UUID: Session]
    }

    /// Assembles the snapshot straight from the store. Returns nil when a
    /// fetch fails: callers must skip the push and let the watch keep its
    /// last good state — pushing an empty snapshot instead would wipe the
    /// watch UI until the next successful sync.
    static func snapshot(
        in context: ModelContext,
        at now: Date = .now,
        calendar: Calendar = .current
    ) -> WatchSnapshot? {
        do {
            let metrics = try context.fetch(FetchDescriptor<Metric>())
            return snapshot(
                from: metrics,
                index: try sessionIndex(in: context, at: now, calendar: calendar),
                at: now,
                calendar: calendar
            )
        } catch {
            SyncLog.error("Watch snapshot fetch failed: \(error)")
            return nil
        }
    }

    /// Assembles the snapshot from already-loaded metrics, deriving totals
    /// from their session relationships.
    static func snapshot(
        from metrics: [Metric],
        at now: Date = .now,
        calendar: Calendar = .current
    ) -> WatchSnapshot {
        snapshot(from: metrics, index: nil, at: now, calendar: calendar)
    }

    private static func snapshot(
        from metrics: [Metric],
        index: SessionIndex?,
        at now: Date,
        calendar: Calendar
    ) -> WatchSnapshot {
        // Archived metrics leave the wrist with the rest of the day surfaces.
        let sorted = metrics.unarchived.sorted { $0.createdAt < $1.createdAt }
        return WatchSnapshot(
            metrics: sorted.compactMap {
                metricSnapshot(for: $0, index: index, at: now, calendar: calendar)
            },
            day: calendar.startOfDay(for: now),
            builtAt: now
        )
    }

    /// Fetches only what today's totals need — sessions started today plus
    /// the running ones — instead of touching each metric's whole history.
    /// The totals mirror `SessionStatistics.todayTotal(from:)`: completed
    /// sessions only, credited to the day they started.
    private static func sessionIndex(
        in context: ModelContext,
        at now: Date,
        calendar: Calendar
    ) throws -> SessionIndex {
        let dayStart = calendar.startOfDay(for: now)
        let todays = try context.fetch(
            FetchDescriptor<Session>(predicate: #Predicate { $0.startedAt >= dayStart })
        )
        let running = try context.fetch(
            FetchDescriptor<Session>(predicate: Session.isRunningPredicate)
        )
        var totals = [UUID: Double]()
        for session in todays {
            guard !session.isRunning,
                  calendar.isDate(session.startedAt, inSameDayAs: now),
                  let id = session.metric?.stableID
            else { continue }
            totals[id, default: 0] += session.trackingValue
        }
        var runningByMetric = [UUID: Session]()
        for session in running {
            guard let id = session.metric?.stableID else { continue }
            // Earliest start wins, keeping the pick deterministic if a
            // metric ever holds two open sessions.
            if let held = runningByMetric[id], held.startedAt <= session.startedAt { continue }
            runningByMetric[id] = session
        }
        return SessionIndex(todayTotals: totals, running: runningByMetric)
    }

    private static func metricSnapshot(
        for metric: Metric,
        index: SessionIndex?,
        at now: Date,
        calendar: Calendar
    ) -> WatchMetricSnapshot? {
        guard let id = metric.stableID else { return nil }
        let running: Session?
        let todayTotal: Double
        if let index {
            running = index.running[id]
            todayTotal = index.todayTotals[id] ?? 0
        } else {
            running = SessionService.activeSession(for: metric)
            todayTotal = SessionStatistics.todayTotal(
                from: metric.sessions, now: now, calendar: calendar
            )
        }
        return WatchMetricSnapshot(
            id: id,
            name: metric.name,
            measurementType: metric.measurementType,
            unit: metric.unit,
            icon: metric.displayIcon,
            colorName: metric.colorName,
            runningSince: running?.startedAt,
            todayTotal: todayTotal,
            dailyGoal: metric.dailyGoal,
            excludedWeekdays: metric.excludedWeekdays,
            countdownDuration: running?.countdownDuration,
            healthSourceRaw: metric.healthSourceRaw,
            binaryGoalRetiredAt: metric.binaryGoalRetiredAt,
            countLogStyleRaw: metric.countLogStyleRaw
        )
    }
}
