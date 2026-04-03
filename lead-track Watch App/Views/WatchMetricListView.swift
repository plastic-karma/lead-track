import SwiftData
import SwiftUI

struct WatchMetricListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Metric.createdAt) private var metrics: [Metric]
    @Query(filter: #Predicate<Session> { $0.endedAt == nil })
    private var runningSessions: [Session]

    var body: some View {
        List {
            ForEach(metrics) { metric in
                NavigationLink(value: metric) {
                    metricRow(metric)
                }
            }
        }
        .navigationTitle("Metrics")
        .overlay {
            if metrics.isEmpty {
                ContentUnavailableView(
                    "No Metrics",
                    systemImage: "chart.bar",
                    description: Text("Add metrics on iPhone.")
                )
            }
        }
    }

    private func metricRow(_ metric: Metric) -> some View {
        HStack {
            Image(systemName: metric.icon ?? "clock")
                .foregroundStyle(.tint)
            Text(metric.name)
                .lineLimit(1)
            Spacer()
            if hasActiveSession(metric) {
                Circle()
                    .fill(.red)
                    .frame(width: 8, height: 8)
            }
        }
    }

    private func hasActiveSession(_ metric: Metric) -> Bool {
        let id = metric.persistentModelID
        return runningSessions.contains {
            $0.metric?.persistentModelID == id
        }
    }
}
