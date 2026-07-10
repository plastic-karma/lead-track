#if canImport(ActivityKit) && !os(macOS)
import ActivityKit
import AppIntents
import Foundation
import SwiftData
import WidgetKit

struct StopTimerIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Stop Timer"

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
        let descriptor = FetchDescriptor<Session>(
            predicate: Session.isRunningPredicate
        )
        let running = try context.fetch(descriptor)
        var names: Set<String> = []
        for session in running where matches(session) {
            if let name = session.metric?.name {
                names.insert(name)
            }
            SessionService.stopSession(session)
        }
        try context.save()
        await endActivities(for: names)
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

extension StopTimerIntent {
    /// Whether a running session belongs to the targeted metric — or to any
    /// metric when no id is set (the Live Activity's Stop button stops all).
    private func matches(_ session: Session) -> Bool {
        metricID.isEmpty || session.metric?.stableID?.uuidString == metricID
    }

    private func endActivities(for metricNames: Set<String>) async {
        for activity in Activity<TimerActivityAttributes>.activities {
            if metricID.isEmpty || metricNames.contains(activity.attributes.metricName) {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
}
#endif
