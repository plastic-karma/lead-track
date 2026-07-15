import Foundation
import HealthKit
import os
import SwiftData
import WidgetKit

/// Keeps every health-linked metric's mirrored sessions in step with Apple
/// Health: one value-session per day over a trailing window (see
/// `HealthDailyMirror`), refreshed when the app comes to the foreground and
/// when a health metric is created or opened.
///
/// Opt-in by design: until the user saves a health-linked metric nothing
/// here runs — no `HKHealthStore` is created and no permission prompt can
/// appear. Read access is requested per source, only from `connect`, which
/// runs when the user saves such a metric or taps Sync Now.
@MainActor
final class HealthMetricSyncService {
    static let shared = HealthMetricSyncService()

    /// How many trailing days each refresh rewrites. Workouts logged late
    /// and edits inside this window are picked up; older days stay frozen
    /// with their last-synced values.
    static let syncWindowDays = 30

    /// Serializes passes so an overlapping trigger (scene phase, Sync Now,
    /// detail view) can never interleave with one already in flight and
    /// apply the same mirror plan twice. See `HealthServicePassQueue`.
    private let passes = HealthServicePassQueue()

    /// Whether this device has health data at all — gates every entry point
    /// and hides the Health option from the metric form.
    var isAvailable: Bool {
        HealthServices.isAvailable
    }

    /// Creation path (and the explicit Sync Now button): asks for read
    /// access to exactly the metric's source types, then mirrors the window.
    /// Re-running is cheap — the system prompt only appears while the choice
    /// is still undecided.
    func connect(metricID: UUID, container: ModelContainer) async {
        guard isAvailable else { return }
        await passes.run {
            await self.performConnect(metricID: metricID, container: container)
        }
    }

    /// Foreground path: refreshes every health-linked metric. Returns
    /// immediately — before touching HealthKit — when there are none.
    func refreshAll(container: ModelContainer) async {
        guard isAvailable else { return }
        await passes.run {
            await self.performRefreshAll(container: container)
        }
    }

    /// Detail-view path: silently refreshes one metric, without ever
    /// presenting a permission prompt.
    func refreshMetric(metricID: UUID, container: ModelContainer) async {
        guard isAvailable else { return }
        await passes.run {
            await self.performRefreshMetric(metricID: metricID, container: container)
        }
    }
}

// MARK: - Passes

extension HealthMetricSyncService {
    private func performConnect(metricID: UUID, container: ModelContainer) async {
        let context = ModelContext(container)
        guard let metric = try? Metric.find(stableID: metricID, in: context),
              let source = metric.healthSource
        else { return }
        let reader = HealthKitMetricReader(store: HealthServices.store())
        do {
            try await reader.requestReadAccess(for: source)
            try await refresh(metric, with: reader, in: context)
        } catch {
            HealthServices.report("Health sync connect", error)
        }
    }

    private func performRefreshAll(container: ModelContainer) async {
        let context = ModelContext(container)
        let linked = HealthServices.metrics(
            matching: #Predicate<Metric> { $0.healthSourceRaw != nil },
            in: context
        )
        guard !linked.isEmpty else { return }
        let reader = HealthKitMetricReader(store: HealthServices.store())
        for metric in linked {
            do {
                try await refresh(metric, with: reader, in: context)
            } catch {
                HealthServices.report("Health refresh", error)
            }
        }
    }

    private func performRefreshMetric(metricID: UUID, container: ModelContainer) async {
        let context = ModelContext(container)
        guard let metric = try? Metric.find(stableID: metricID, in: context),
              metric.isHealthLinked
        else { return }
        do {
            try await refresh(
                metric,
                with: HealthKitMetricReader(store: HealthServices.store()),
                in: context
            )
        } catch {
            HealthServices.report("Health refresh", error)
        }
    }
}

// MARK: - Mirroring

extension HealthMetricSyncService {
    /// Mirrors one metric's trailing window. Throws — without stamping
    /// `lastHealthSyncAt` — when the HealthKit fetch or the save fails, so a
    /// failed pass never deletes mirrored sessions and never pretends it
    /// synced.
    private func refresh(
        _ metric: Metric,
        with reader: HealthKitMetricReader,
        in context: ModelContext
    ) async throws {
        guard let source = metric.healthSource else { return }
        let window = HealthDailyMirror.window(days: Self.syncWindowDays)
        let fetched = try await reader.dayTotals(for: source, window: window)
        let operations = HealthDailyMirror.plan(
            window: window,
            fetched: fetched,
            existing: existingByDay(metric: metric, window: window)
        )
        apply(operations, to: metric, in: context)
        metric.lastHealthSyncAt = .now
        try context.save()
        if !operations.isEmpty {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    private func apply(
        _ operations: [HealthDailyMirror.Operation],
        to metric: Metric,
        in context: ModelContext
    ) {
        for operation in operations {
            switch operation {
            case let .insert(day, value):
                context.insert(
                    Session(metric: metric, startedAt: day, endedAt: day, value: value)
                )
            case let .update(day, value):
                sessions(of: metric, on: day).first?.value = value
            case let .delete(day):
                for session in sessions(of: metric, on: day) {
                    context.delete(session)
                }
            }
        }
    }

    private func existingByDay(
        metric: Metric,
        window: [Date]
    ) -> [Date: [Double]] {
        guard let start = window.first else { return [:] }
        let calendar = Calendar.current
        var byDay: [Date: [Double]] = [:]
        let mirrored = metric.sessions.filter {
            !$0.isRunning && $0.startedAt >= start
        }
        for session in mirrored {
            let day = calendar.startOfDay(for: session.startedAt)
            byDay[day, default: []].append(session.trackingValue)
        }
        return byDay
    }

    private func sessions(of metric: Metric, on day: Date) -> [Session] {
        let calendar = Calendar.current
        return metric.sessions.filter {
            calendar.isDate($0.startedAt, inSameDayAs: day)
        }
    }
}

// MARK: - Shared Plumbing

/// The non-domain scaffolding `HealthMetricSyncService` and
/// `HealthSessionExportService` share, kept in one place so a fix to it can
/// never drift between them: one app-wide `HKHealthStore`, the availability
/// gate, the predicate fetch, and the log channel.
@MainActor
enum HealthServices {
    private static var healthStore: HKHealthStore?

    /// Whether this device has health data at all.
    static var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    /// The app's one `HKHealthStore`, shared by both health services so
    /// authorization state has a single home — created lazily, so no
    /// HealthKit object exists until the user opts a metric into Health.
    static func store() -> HKHealthStore {
        if let healthStore { return healthStore }
        let created = HKHealthStore()
        healthStore = created
        return created
    }

    /// The metrics a pass covers, fetched fresh from `context`.
    static func metrics(
        matching predicate: Predicate<Metric>,
        in context: ModelContext
    ) -> [Metric] {
        let descriptor = FetchDescriptor<Metric>(predicate: predicate)
        return (try? context.fetch(descriptor)) ?? []
    }

    /// Logs a failed pass step, which both services previously swallowed
    /// whole. Only the step name and the error's description are recorded —
    /// never metric names, values, or other user content.
    static func report(_ step: String, _ error: Error) {
        log.error("\(step, privacy: .public) failed: \(String(describing: error), privacy: .public)")
    }

    private static let log = Logger(
        subsystem: "plastickarma.lead-track",
        category: "Health"
    )
}

/// Runs each submitted pass strictly after every earlier one has finished.
/// The health services are reentrant `@MainActor` singletons whose passes
/// suspend at HealthKit awaits, so without this two overlapping passes plan
/// against the same pre-state and apply it twice — duplicate records in
/// Apple Health on the write side (which never self-heal), duplicate
/// mirrored day-sessions on the read side.
@MainActor
final class HealthServicePassQueue {
    private var lastPass: Task<Void, Never>?

    /// Enqueues `pass` and returns once it has run — callers still observe
    /// their own pass completing, they just can never overlap another.
    func run(_ pass: @escaping @MainActor () async -> Void) async {
        let previous = lastPass
        let next = Task {
            await previous?.value
            await pass()
        }
        lastPass = next
        await next.value
    }
}
