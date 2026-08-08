#if canImport(ActivityKit) && os(iOS)
import ActivityKit
import AppIntents
import Foundation
import SwiftData
import WidgetKit

/// Performs the current one-tap action for a metric selected by a system
/// control. The metric is fetched again at execution time so a control never
/// acts on stale type, archive, or Health-link state from its rendered value.
struct MetricControlIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Use Metric"
    static var isDiscoverable = false

    @Parameter(title: "Metric ID") var metricID: String

    init() {
        metricID = ""
    }

    init(metricID: String) {
        self.metricID = metricID
    }

    func perform() async throws -> some IntentResult {
        guard let container = SharedModelContainer.shared else { return .result() }
        let context = ModelContext(container)
        guard let metric = try targetMetric(in: context) else { return .result() }
        performAction(for: metric, in: context)
        try context.save()
        WidgetCenter.shared.reloadAllTimelines()
        ControlCenter.shared.reloadControls(ofKind: WidgetKinds.favoriteMetricControl)
        return .result()
    }

    private func targetMetric(in context: ModelContext) throws -> Metric? {
        guard let id = UUID(uuidString: metricID),
              let metric = try Metric.find(stableID: id, in: context),
              metric.isControlEligible
        else { return nil }
        return metric
    }

    private func performAction(for metric: Metric, in context: ModelContext) {
        switch metric.measurementType {
        case .duration:
            if let running = SessionService.storedRunningSession(
                for: metric,
                in: context
            ) {
                SessionService.stopSession(running)
            } else {
                SessionService.startSession(for: metric, in: context)
            }
        case .count:
            SessionService.logCount(1, for: metric, in: context)
        case .binary:
            SessionService.toggleBinaryDay(for: metric, in: context)
        }
    }
}
#endif
