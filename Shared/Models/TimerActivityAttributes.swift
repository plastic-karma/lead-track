#if canImport(ActivityKit)
import ActivityKit
import Foundation

struct TimerActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var startedAt: Date
    }

    var metricName: String
    var projectName: String?
    var icon: String
}
#endif
