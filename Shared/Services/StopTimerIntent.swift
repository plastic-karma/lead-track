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
        var stopped = StoppedMetrics()
        for session in running where matches(session) {
            stopped.record(session.metric)
            SessionService.stopSession(session)
        }
        try context.save()
        await endActivities(for: stopped)
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

    /// The identities of the metrics whose sessions a stop pass ended:
    /// stable IDs are the real identity; names exist only to match
    /// activities started by builds that predate the ID field. Matching by
    /// name alone ended the wrong metric's Live Activity whenever two
    /// metrics shared a name, and a rename orphaned the activity for good.
    private struct StoppedMetrics {
        private(set) var ids: Set<String> = []
        private(set) var names: Set<String> = []

        mutating func record(_ metric: Metric?) {
            guard let metric else { return }
            names.insert(metric.name)
            if let id = metric.stableID?.uuidString {
                ids.insert(id)
            }
        }

        func matches(_ attributes: TimerActivityAttributes) -> Bool {
            guard let id = attributes.metricID else {
                return names.contains(attributes.metricName)
            }
            return ids.contains(id)
        }
    }

    private func endActivities(for stopped: StoppedMetrics) async {
        for activity in Activity<TimerActivityAttributes>.activities {
            if metricID.isEmpty || stopped.matches(activity.attributes) {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
}
#endif
