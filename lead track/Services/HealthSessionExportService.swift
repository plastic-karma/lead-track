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

    /// Serializes passes so a scene-phase `exportAll` can never interleave
    /// with an in-flight `connect` (or another `exportAll`) at an await and
    /// send the same pending session twice — duplicate records written into
    /// Apple Health never self-heal. See `HealthServicePassQueue`.
    private let passes = HealthServicePassQueue()

    /// Whether this device has health data at all — gates every entry point
    /// and hides the export option from the metric form.
    var isAvailable: Bool {
        HealthServices.isAvailable
    }

    /// Save path: asks for write access to exactly the metric's target
    /// record type, then sends what is already pending. Re-running is cheap
    /// — the system prompt only appears while the choice is still undecided.
    func connect(metricID: UUID, container: ModelContainer) async {
        guard isAvailable else { return }
        await passes.run {
            await self.performConnect(metricID: metricID, container: container)
        }
    }

    /// Scene-phase path: sends every pending session across metrics.
    /// Returns immediately — before touching HealthKit — when no metric
    /// exports.
    func exportAll(container: ModelContainer) async {
        guard isAvailable else { return }
        await passes.run {
            await self.performExportAll(container: container)
        }
    }
}

// MARK: - Passes

extension HealthSessionExportService {
    private func performConnect(metricID: UUID, container: ModelContainer) async {
        let context = ModelContext(container)
        guard let metric = try? Metric.find(stableID: metricID, in: context),
              let target = metric.healthExportTarget
        else { return }
        let writer = HealthKitSessionWriter(store: HealthServices.store())
        do {
            try await writer.requestShareAccess(for: target)
        } catch {
            // A failed prompt doesn't decide access — the authorization
            // check in export(_:with:in:) still gates every write.
            HealthServices.report("Health export authorization", error)
        }
        await export(metric, with: writer, in: context)
    }

    private func performExportAll(container: ModelContainer) async {
        let context = ModelContext(container)
        let exporting = HealthServices.metrics(
            matching: #Predicate<Metric> { $0.healthExportRaw != nil },
            in: context
        )
        guard !exporting.isEmpty else { return }
        let writer = HealthKitSessionWriter(store: HealthServices.store())
        for metric in exporting {
            guard await export(metric, with: writer, in: context) else { return }
        }
    }
}

// MARK: - Sending

extension HealthSessionExportService {
    /// Sends the metric's pending sessions. Returns false when the pass must
    /// stop because export stamps no longer persist.
    @discardableResult
    private func export(
        _ metric: Metric,
        with writer: HealthKitSessionWriter,
        in context: ModelContext
    ) async -> Bool {
        guard let target = metric.healthExportTarget,
              metric.supportsHealthExport,
              writer.isAuthorized(for: target)
        else { return true }
        let pending = HealthSessionExport.pending(
            in: metric.sessions,
            enabledAt: metric.healthExportEnabledAt
        )
        return await send(pending, as: target, with: writer, in: context)
    }

    /// Writes each session and immediately persists its stamp. A failed
    /// write leaves the session unstamped, so the next pass simply retries
    /// it. A stamp that fails to save aborts the whole pass instead: Health
    /// already holds that record, and writing on while stamps are being lost
    /// would hand every later pass the same sessions again — as duplicates
    /// Apple Health keeps forever.
    private func send(
        _ sessions: [Session],
        as target: HealthExportTarget,
        with writer: HealthKitSessionWriter,
        in context: ModelContext
    ) async -> Bool {
        for session in sessions {
            guard let interval = HealthSessionExport.interval(of: session),
                  await write(interval, as: target, with: writer)
            else { continue }
            session.healthExportedAt = .now
            do {
                try context.save()
            } catch {
                HealthServices.report("Persisting Health export stamps", error)
                return false
            }
        }
        return true
    }

    private func write(
        _ interval: DateInterval,
        as target: HealthExportTarget,
        with writer: HealthKitSessionWriter
    ) async -> Bool {
        do {
            try await writer.write(interval, as: target)
            return true
        } catch {
            HealthServices.report("Health export write", error)
            return false
        }
    }
}
