import SwiftUI

/// Top-of-list summary of how many metrics have hit their daily and weekly
/// goals. Only rings with at least one active goal appear, and today's rest-day
/// metrics are skipped from the daily count, so off days never drag it down.
struct GoalSummaryView: View {
    let metrics: [Metric]

    private var daily: GoalSummary {
        GoalSummary.daily(for: metrics)
    }

    private var weekly: GoalSummary {
        GoalSummary.weekly(for: metrics)
    }

    var body: some View {
        if daily.hasGoals || weekly.hasGoals {
            Section("Goal Progress") {
                Grid(horizontalSpacing: 16, verticalSpacing: 12) {
                    GridRow {
                        if daily.hasGoals {
                            GoalTrackerRing(label: "Daily", summary: daily)
                        }
                        if weekly.hasGoals {
                            GoalTrackerRing(label: "Weekly", summary: weekly)
                        }
                    }
                }
            }
        }
    }
}
