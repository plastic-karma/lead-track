import SwiftUI

/// One list row per metric: duration metrics toggle their timer on tap,
/// count metrics open a quick-log screen.
struct WatchMetricRow: View {
    let metric: WatchMetricSnapshot

    var body: some View {
        switch metric.measurementType {
        case .duration:
            WatchTimerRow(metric: metric)
        case .count:
            NavigationLink {
                WatchLogView(metric: metric)
            } label: {
                WatchMetricLabel(
                    metric: metric,
                    accessory: "plus.circle.fill",
                    accessoryColor: MetricColor.color(named: metric.colorName)
                )
            }
        }
    }
}
