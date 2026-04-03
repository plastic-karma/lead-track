import SwiftData
import SwiftUI

struct MetricListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Metric.createdAt) private var metrics: [Metric]
    @Query(filter: #Predicate<Session> { $0.endedAt == nil })
    private var runningSessions: [Session]
    @State private var showingAddSheet = false

    var body: some View {
        List {
            ForEach(metrics) { metric in
                NavigationLink(value: metric) {
                    metricRow(metric)
                }
            }
            .onDelete(perform: deleteMetrics)
        }
        .navigationTitle("Metrics")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                EditButton()
            }
            ToolbarItem {
                Button { showingAddSheet = true } label: {
                    Label("Add Metric", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            MetricFormView()
        }
        .overlay {
            if metrics.isEmpty {
                ContentUnavailableView(
                    "No Metrics",
                    systemImage: "chart.bar",
                    description: Text("Tap + to add a metric.")
                )
            }
        }
    }

    private func metricRow(_ metric: Metric) -> some View {
        HStack {
            Image(systemName: metric.icon ?? "clock")
                .foregroundStyle(.tint)
                .frame(width: 30)
            Text(metric.name)
            Spacer()
            if hasActiveSession(metric) {
                Image(systemName: "record.circle")
                    .foregroundStyle(.red)
                    .symbolEffect(.pulse)
            }
        }
    }

    private func hasActiveSession(_ metric: Metric) -> Bool {
        let id = metric.persistentModelID
        return runningSessions.contains {
            $0.metric?.persistentModelID == id
        }
    }

    private func deleteMetrics(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(metrics[index])
            }
        }
    }
}
