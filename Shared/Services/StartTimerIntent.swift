#if canImport(ActivityKit) && !os(macOS)
import ActivityKit
import AppIntents
import Foundation
import SwiftData
import WidgetKit

/// Starts the timer for a duration metric from a widget or Shortcut, without
/// opening the app. Conforms to `LiveActivityIntent` so it may start the Live
/// Activity even when run from the background.
struct StartTimerIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Start Timer"

    @Parameter(title: "Metric ID") var metricID: String

    init() {
        metricID = ""
    }

    init(metricID: String) {
        self.metricID = metricID
    }

    func perform() async throws -> some IntentResult {
        // The cached per-process container: rebuilding the stack (and
        // re-running the stable-ID backfill) on every widget tap is wasted
        // work in the extension's tight budget.
        guard let container = SharedModelContainer.shared else { return .result() }
        let context = ModelContext(container)
        if let metric = try targetMetric(in: context) {
            SessionService.startSession(for: metric, in: context)
            try context.save()
        }
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }

    private func targetMetric(in context: ModelContext) throws -> Metric? {
        guard let id = UUID(uuidString: metricID) else { return nil }
        guard let metric = try Metric.find(stableID: id, in: context),
              !metric.isHealthLinked,
              !metric.isArchived
        else { return nil }
        return metric
    }
}
#endif
