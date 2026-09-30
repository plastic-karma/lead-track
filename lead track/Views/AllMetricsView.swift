import SwiftData
import SwiftUI
import WidgetKit

/// The path value the Aspirations menu appends before this screen. Keeping
/// the screen in `ContentView`'s path lets deep-link resets replace the whole
/// Aspirations stack, just like every existing metric and aspiration route.
struct AllMetricsRoute: Hashable {}

/// Every metric in one place, reached from the Aspirations tab. Unlike the
/// day and week surfaces this includes metrics that have been set aside, with
/// filters for favorites and each archive state. Rows only navigate; archive
/// side effects stay on the metric detail screen.
struct AllMetricsView: View {
    @Query(sort: \Metric.createdAt) private var metrics: [Metric]
    @State private var filter = MetricStatusFilter.all

    var body: some View {
        VStack(spacing: 0) {
            filterPicker
            AllMetricsContent(metrics: metrics, filter: filter)
        }
        .background { Theme.washedScreen }
        .navigationTitle("All Metrics")
        .navigationBarTitleDisplayMode(.inline)
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
}

// MARK: - Content

private struct AllMetricsContent: View {
    let metrics: [Metric]
    let filter: MetricStatusFilter
    private var visibleMetrics: [Metric] {
        let ordered = metrics.inDisplayOrder
        return switch filter {
        case .favourite:
            ordered.filter(\.isFavorite)
        case .active:
            ordered.filter { !$0.isArchived }
        case .all:
            ordered
        case .archived:
            ordered.filter(\.isArchived)
        }
    }

    var body: some View {
        let visible = visibleMetrics
        if visible.isEmpty {
            emptyState
        } else {
            List(visible) { metric in
                AllMetricRow(metric: metric)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }
}

private struct AllMetricRow: View {
    @Environment(\.modelContext) private var modelContext
    let metric: Metric

    var body: some View {
        NavigationLink(value: metric) {
            label
        }
        .swipeActions(edge: .leading) {
            if !metric.isHealthLinked {
                favoriteButton
            }
        }
    }

    private var label: some View {
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

    private var favoriteButton: some View {
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

extension AllMetricsContent {
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
        case .favourite: "No Favourite Metrics"
        case .active: "No Active Metrics"
        case .all: "No Metrics"
        case .archived: "Nothing Archived"
        }
    }

    private var emptySystemImage: String {
        switch filter {
        case .favourite: "star"
        case .active, .all: "list.bullet"
        case .archived: "archivebox"
        }
    }

    private var emptyDescription: String {
        switch filter {
        case .favourite: "Metrics you mark as favourites will appear here."
        case .active: "Create or unarchive a metric to see it here."
        case .all: "Metrics you create will appear here."
        case .archived: "Metrics you archive will appear here."
        }
    }
}

private enum MetricStatusFilter: String, CaseIterable, Identifiable {
    case favourite = "Favourite"
    case active = "Active"
    case all = "All"
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
