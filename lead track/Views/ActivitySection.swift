import SwiftUI

/// The "Activity" heatmap section shown on detail screens, hidden until
/// there is at least one logged day.
struct ActivitySection: View {
    let dailyTotals: [DailyTotal]
    let tint: Color

    var body: some View {
        if !dailyTotals.isEmpty {
            Section("Activity") {
                CalendarHeatmapView(dailyTotals: dailyTotals, tint: tint)
            }
        }
    }
}
