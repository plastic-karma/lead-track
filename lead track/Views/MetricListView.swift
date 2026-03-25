import SwiftData
import SwiftUI

struct MetricListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Metric.createdAt) private var metrics: [Metric]
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
        metric.sessions.contains { $0.isRunning }
    }

    private func deleteMetrics(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(metrics[index])
            }
        }
    }
}
