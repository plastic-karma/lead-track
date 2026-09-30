import SwiftData
import SwiftUI

/// The card-based attachment editor. Whole metrics subsume their selected
/// projects without clearing them, so those selections return when detached.
struct AspirationFeedPicker: View {
    @Query(sort: \Metric.createdAt) private var metrics: [Metric]
    @Binding var selectedMetrics: Set<Metric>
    @Binding var selectedProjects: Set<Project>
    let tint: Color
    let prominentTint: Color
    @State private var showingNewMetric = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            AspirationFeedHeader(
                count: feedCount, tint: tint, showingNewMetric: $showingNewMetric
            )
            if metrics.isEmpty {
                Text("No metrics yet. Add one to start feeding this aspiration.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
                ForEach(metrics) { metric in
                    AspirationFeedMetricCard(
                        metric: metric,
                        isSelected: $selectedMetrics[selected: metric],
                        selectedProjects: $selectedProjects,
                        prominentTint: prominentTint
                    )
                }
                Text("Tap a row to expand and pick individual projects. Totals recompute live as membership changes.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .sheet(isPresented: $showingNewMetric) {
            MetricFormView()
        }
    }

    private var feedCount: Int {
        selectedMetrics.count + selectedProjects.reduce(into: 0) { count, project in
            if let parent = project.metric, selectedMetrics.contains(parent) { return }
            count += 1
        }
    }
}

private struct AspirationFeedHeader: View {
    let count: Int
    let tint: Color
    @Binding var showingNewMetric: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            FormEyebrow(text: "What feeds this · \(count)", tint: tint)
            Spacer()
            Button { showingNewMetric = true } label: {
                Label("Add", systemImage: "plus")
                    .font(.caption.weight(.semibold))
            }
            .tint(tint)
        }
    }
}

private struct AspirationFeedMetricCard: View {
    let metric: Metric
    @Binding var isSelected: Bool
    @Binding var selectedProjects: Set<Project>
    let prominentTint: Color
    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button(action: primaryTap) {
                    AspirationFeedMetricLabel(
                        name: metric.name,
                        icon: metric.displayIcon,
                        tint: metric.prominentColor,
                        subtitle: subtitle,
                        hasProjects: !metric.projects.isEmpty,
                        isExpanded: isExpanded
                    )
                }
                .buttonStyle(.plain)
                Button { isSelected.toggle() } label: {
                    SelectionBadge(isSelected: isSelected, tint: prominentTint)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Include \(metric.name)")
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
            .padding(14)
            if isExpanded {
                VStack(spacing: 0) {
                    Divider().padding(.leading, 14)
                    ForEach(metric.projects.inDisplayOrder) { project in
                        AspirationFeedProjectRow(
                            name: project.name,
                            isSelected: $selectedProjects[selected: project],
                            whole: isSelected,
                            tint: prominentTint
                        )
                    }
                }
            }
        }
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.cardBackground)
        }
    }

    private var subtitle: String {
        if isSelected { return "Whole metric · \(structureLabel)" }
        let picked = metric.projects.reduce(into: 0) { count, project in
            if selectedProjects.contains(project) { count += 1 }
        }
        if picked > 0 { return "\(picked) of \(metric.projects.count) projects" }
        return structureLabel
    }

    private var structureLabel: String {
        let count = metric.projects.count
        if count > 0 { return count == 1 ? "1 project" : "\(count) projects" }
        return metric.measurementType == .duration ? "timer" : "counter"
    }

    private func primaryTap() {
        if metric.projects.isEmpty {
            isSelected.toggle()
        } else {
            withAnimation(.snappy) { isExpanded.toggle() }
        }
    }
}

private struct AspirationFeedMetricLabel: View {
    let name: String
    let icon: String
    let tint: Color
    let subtitle: String
    let hasProjects: Bool
    let isExpanded: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background {
                    RoundedRectangle(cornerRadius: 10, style: .continuous).fill(tint)
                }
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            if hasProjects {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
            }
        }
        .contentShape(Rectangle())
    }
}

private struct AspirationFeedProjectRow: View {
    let name: String
    @Binding var isSelected: Bool
    let whole: Bool
    let tint: Color

    var body: some View {
        Button { isSelected.toggle() } label: {
            HStack(spacing: 12) {
                Text(name)
                    .font(.subheadline)
                    .foregroundStyle(whole ? .secondary : .primary)
                Spacer(minLength: 4)
                SelectionBadge(isSelected: whole || isSelected, tint: tint, size: 22)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .padding(.leading, 38)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(whole)
        .accessibilityLabel("Include \(name)")
        .accessibilityAddTraits(whole || isSelected ? .isSelected : [])
    }
}
