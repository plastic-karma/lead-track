#if canImport(ActivityKit)
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
        let container = try SharedModelContainer.create()
        let context = ModelContext(container)
        let metrics = try context.fetch(FetchDescriptor<Metric>())
        if let metric = metrics.first(where: { $0.stableID?.uuidString == metricID }) {
            SessionService.startSession(for: metric, in: context)
            try context.save()
        }
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
#endif
