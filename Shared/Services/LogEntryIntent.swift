import AppIntents
import Foundation
import SwiftData
import WidgetKit

/// Logs a single count entry for a count metric from a widget or Shortcut,
/// without opening the app. Adds 1 in the metric's unit.
struct LogEntryIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Entry"

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
            let entry = Session(
                metric: metric,
                project: metric.defaultProject,
                startedAt: .now,
                endedAt: .now,
                value: 1
            )
            context.insert(entry)
            try context.save()
        }
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
