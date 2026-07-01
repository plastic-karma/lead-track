import Foundation
import HealthKit
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

    private var healthStore: HKHealthStore?

    /// Whether this device has health data at all — gates every entry point
    /// and hides the Health option from the metric form.
    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    /// Creation path (and the explicit Sync Now button): asks for read
    /// access to exactly the metric's source types, then mirrors the window.
    /// Re-running is cheap — the system prompt only appears while the choice
    /// is still undecided.
    func connect(metricID: UUID, container: ModelContainer) async {
        guard isAvailable else { return }
        let context = ModelContext(container)
        guard let metric = try? Metric.find(stableID: metricID, in: context),
              let source = metric.healthSource
        else { return }
        let reader = HealthKitMetricReader(store: store())
        try? await reader.requestReadAccess(for: source)
        await refresh(metric, with: reader, in: context)
    }

    /// Foreground path: refreshes every health-linked metric. Returns
    /// immediately — before touching HealthKit — when there are none.
    func refreshAll(container: ModelContainer) async {
        guard isAvailable else { return }
        let context = ModelContext(container)
        let linked = healthLinkedMetrics(in: context)
        guard !linked.isEmpty else { return }
        let reader = HealthKitMetricReader(store: store())
        for metric in linked {
            await refresh(metric, with: reader, in: context)
        }
    }

    /// Detail-view path: silently refreshes one metric, without ever
    /// presenting a permission prompt.
    func refreshMetric(metricID: UUID, container: ModelContainer) async {
        guard isAvailable else { return }
        let context = ModelContext(container)
        guard let metric = try? Metric.find(stableID: metricID, in: context),
              metric.isHealthLinked
        else { return }
        await refresh(metric, with: HealthKitMetricReader(store: store()), in: context)
    }
}

// MARK: - Mirroring

extension HealthMetricSyncService {
    private func refresh(
        _ metric: Metric,
        with reader: HealthKitMetricReader,
        in context: ModelContext
    ) async {
        guard let source = metric.healthSource else { return }
        let window = HealthDailyMirror.window(days: Self.syncWindowDays)
        guard let fetched = try? await reader.dayTotals(for: source, window: window)
        else { return }
        let operations = HealthDailyMirror.plan(
            window: window,
            fetched: fetched,
            existing: existingByDay(metric: metric, window: window)
        )
        apply(operations, to: metric, in: context)
        metric.lastHealthSyncAt = .now
        try? context.save()
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

    private func healthLinkedMetrics(in context: ModelContext) -> [Metric] {
        let descriptor = FetchDescriptor<Metric>(
            predicate: #Predicate { $0.healthSourceRaw != nil }
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    private func store() -> HKHealthStore {
        if let healthStore { return healthStore }
        let created = HKHealthStore()
        healthStore = created
        return created
    }
}
