import SwiftUI

/// The "Activity" heatmap section shown on detail screens, hidden until
/// there is at least one logged day.
struct ActivitySection: View {
    let dailyTotals: [DailyTotal]
    let measurementType: MeasurementType
    let unit: String?
    let tint: Color

    var body: some View {
        if !dailyTotals.isEmpty {
            Section("Activity") {
                CalendarHeatmapView(
                    dailyTotals: dailyTotals, measurementType: measurementType, unit: unit, tint: tint
                )
            }
        }
    }
}
