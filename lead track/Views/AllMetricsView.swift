import SwiftData
import SwiftUI
import WidgetKit

/// The path value the Aspirations menu appends before this screen. Keeping
/// the screen in `ContentView`'s path lets deep-link resets replace the whole
/// Aspirations stack, just like every existing metric and aspiration route.
struct AllMetricsRoute: Hashable {}

/// Every metric in one place, reached from the Aspirations tab. Unlike the
/// day and week surfaces this includes metrics that have been set aside, so
/// the status control can show the whole collection or either shelf alone.
/// Rows only navigate; archive side effects stay on the metric detail screen.
struct AllMetricsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Metric.createdAt) private var metrics: [Metric]
    @State private var filter = MetricStatusFilter.all

    var body: some View {
        VStack(spacing: 0) {
            filterPicker
            content
        }
        .background(Theme.washedScreen)
        .navigationTitle("All Metrics")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Content

extension AllMetricsView {
    private var visibleMetrics: [Metric] {
        let ordered = metrics.inDisplayOrder
        return switch filter {
        case .all:
            ordered
        case .active:
            ordered.filter { !$0.isArchived }
        case .archived:
            ordered.filter(\.isArchived)
        }
    }

    private var filterPicker: some View {
        Picker("Status", selection: $filter) {
            ForEach(MetricStatusFilter.allCases) { option in
                Text(option.rawValue).tag(option)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("Metric Status Filter")
        .padding(.horizontal)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var content: some View {
        if visibleMetrics.isEmpty {
            emptyState
        } else {
            List(visibleMetrics) { metric in
                NavigationLink(value: metric) {
                    row(metric)
                }
                .swipeActions(edge: .leading) {
                    if !metric.isHealthLinked {
                        favoriteButton(metric)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }

    private func row(_ metric: Metric) -> some View {
        HStack(spacing: 12) {
            MetricIcon(systemName: metric.displayIcon, tint: metric.displayColor, size: 34)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(metric.name)
                    .lineLimit(1)
                Text(status(of: metric))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            if metric.isFavorite {
                Image(systemName: "star.fill")
                    .foregroundStyle(metric.displayColor)
                    .accessibilityLabel("Favorite")
            }
        }
        .padding(.vertical, 2)
    }

    private func status(of metric: Metric) -> String {
        guard let date = metric.archivedAt else { return "Active" }
        return "Archived \(date.formatted(.dateTime.month(.abbreviated).day().year()))"
    }

    private func favoriteButton(_ metric: Metric) -> some View {
        Button {
            toggleFavorite(metric)
        } label: {
            Label(
                metric.isFavorite ? "Remove Favorite" : "Favorite",
                systemImage: metric.isFavorite ? "star.slash" : "star"
            )
        }
        .tint(metric.displayColor)
    }

    private func toggleFavorite(_ metric: Metric) {
        let previousValue = metric.isFavorite
        metric.isFavorite.toggle()
        do {
            try modelContext.save()
            ControlCenter.shared.reloadControls(
                ofKind: WidgetKinds.favoriteMetricControl
            )
        } catch {
            metric.isFavorite = previousValue
            StoreLog.error("Favorite save failed: \(error)")
        }
    }
}

// MARK: - Empty state

extension AllMetricsView {
    private var emptyState: some View {
        ContentUnavailableView(
            emptyTitle,
            systemImage: emptySystemImage,
            description: Text(emptyDescription)
        )
        .frame(maxHeight: .infinity)
    }

    private var emptyTitle: String {
        switch filter {
        case .all: "No Metrics"
        case .active: "No Active Metrics"
        case .archived: "Nothing Archived"
        }
    }

    private var emptySystemImage: String {
        filter == .archived ? "archivebox" : "list.bullet"
    }

    private var emptyDescription: String {
        switch filter {
        case .all: "Metrics you create will appear here."
        case .active: "Create or unarchive a metric to see it here."
        case .archived: "Metrics you archive will appear here."
        }
    }
}

private enum MetricStatusFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case active = "Active"
    case archived = "Archived"

    var id: Self {
        self
    }
}

#Preview {
    NavigationStack {
        AllMetricsView()
    }
    .modelContainer(
        for: [Metric.self, Project.self, Session.self],
        inMemory: true
    )
}
