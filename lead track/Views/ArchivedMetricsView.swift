import SwiftData
import SwiftUI

/// The shelf of set-aside metrics, reached from Today's menu once anything
/// is archived. Each row carries the metric's identity, when it was set
/// aside, and the one action that matters here — bringing it back. History,
/// goals, and aspiration links all survive archiving, so an unarchived
/// metric rejoins Today and Week exactly as it left them.
struct ArchivedMetricsView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Metric.createdAt) private var metrics: [Metric]

    /// Most recently set aside first, so the one just archived is the first
    /// thing found here.
    private var archived: [Metric] {
        metrics
            .filter(\.isArchived)
            .sorted { ($0.archivedAt ?? .distantPast) > ($1.archivedAt ?? .distantPast) }
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Archived")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if archived.isEmpty {
            ContentUnavailableView(
                "Nothing Archived",
                systemImage: "archivebox",
                description: Text("Metrics you archive rest here, ready to return.")
            )
        } else {
            List(archived) { metric in
                row(metric)
            }
        }
    }

    private func row(_ metric: Metric) -> some View {
        HStack(spacing: 12) {
            MetricIcon(systemName: metric.displayIcon, tint: metric.displayColor, size: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(metric.name)
                    .lineLimit(1)
                if let date = metric.archivedAt {
                    Text("Archived \(date, format: .dateTime.month(.abbreviated).day().year())")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            Button("Unarchive") { unarchive(metric) }
                .font(.callout.weight(.medium))
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
        }
        .padding(.vertical, 2)
    }

    /// Returns the metric to the day and week surfaces and re-arms its
    /// reminders; the row leaves this list on its own as the query updates.
    private func unarchive(_ metric: Metric) {
        withAnimation(.snappy) {
            metric.unarchive()
        }
        NotificationService.rescheduleMetric(metric)
    }
}

#Preview {
    ArchivedMetricsView()
        .modelContainer(
            for: [Metric.self, Project.self, Session.self],
            inMemory: true
        )
}
