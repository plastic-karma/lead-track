import Foundation
import HealthKit
import SwiftData

/// Sends completed sessions of export-enabled timer metrics to Apple Health:
/// each becomes one mindful session or one workout covering the same span
/// (see `HealthSessionExport`), written once and stamped. Runs when the app
/// changes scene phase and right after the user switches a metric's export
/// on.
///
/// Opt-in by design: until a metric has an export target nothing here runs —
/// no `HKHealthStore` is created and no permission prompt can appear. Write
/// access is requested per target, only from `connect`, which runs when the
/// user saves a metric with export switched on.
@MainActor
final class HealthSessionExportService {
    static let shared = HealthSessionExportService()

    private var healthStore: HKHealthStore?

    /// Whether this device has health data at all — gates every entry point
    /// and hides the export option from the metric form.
    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    /// Save path: asks for write access to exactly the metric's target
    /// record type, then sends what is already pending. Re-running is cheap
    /// — the system prompt only appears while the choice is still undecided.
    func connect(metricID: UUID, container: ModelContainer) async {
        guard isAvailable else { return }
        let context = ModelContext(container)
        guard let metric = try? Metric.find(stableID: metricID, in: context),
              let target = metric.healthExportTarget
        else { return }
        let writer = HealthKitSessionWriter(store: store())
        try? await writer.requestShareAccess(for: target)
        await export(metric, with: writer, in: context)
    }

    /// Scene-phase path: sends every pending session across metrics.
    /// Returns immediately — before touching HealthKit — when no metric
    /// exports.
    func exportAll(container: ModelContainer) async {
        guard isAvailable else { return }
        let context = ModelContext(container)
        let exporting = exportingMetrics(in: context)
        guard !exporting.isEmpty else { return }
        let writer = HealthKitSessionWriter(store: store())
        for metric in exporting {
            await export(metric, with: writer, in: context)
        }
    }
}

// MARK: - Sending

extension HealthSessionExportService {
    private func export(
        _ metric: Metric,
        with writer: HealthKitSessionWriter,
        in context: ModelContext
    ) async {
        guard let target = metric.healthExportTarget,
              metric.supportsHealthExport,
              writer.isAuthorized(for: target)
        else { return }
        let pending = HealthSessionExport.pending(
            in: metric.sessions,
            enabledAt: metric.healthExportEnabledAt
        )
        for session in pending {
            await send(session, as: target, with: writer)
        }
        try? context.save()
    }

    /// A failed write leaves the session unstamped, so the next pass simply
    /// retries it.
    private func send(
        _ session: Session,
        as target: HealthExportTarget,
        with writer: HealthKitSessionWriter
    ) async {
        guard let interval = HealthSessionExport.interval(of: session),
              (try? await writer.write(interval, as: target)) != nil
        else { return }
        session.healthExportedAt = .now
    }

    private func exportingMetrics(in context: ModelContext) -> [Metric] {
        let descriptor = FetchDescriptor<Metric>(
            predicate: #Predicate { $0.healthExportRaw != nil }
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
