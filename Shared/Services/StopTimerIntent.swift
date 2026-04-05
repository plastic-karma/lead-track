#if canImport(ActivityKit)
import ActivityKit
import AppIntents
import Foundation
import SwiftData

struct StopTimerIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Stop Timer"

    func perform() async throws -> some IntentResult {
        let container = try SharedModelContainer.create()
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<Session>(
            predicate: #Predicate { $0.endedAt == nil }
        )
        let runningSessions = try context.fetch(descriptor)
        for session in runningSessions {
            session.endedAt = .now
        }
        try context.save()
        for activity in Activity<TimerActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        return .result()
    }
}
#endif
