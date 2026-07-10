import SwiftData
import SwiftUI

/// The "What feeds this" editor in the aspiration form: every metric as a
/// tappable card you can include whole, or expand to pick individual projects.
/// Selecting a whole metric subsumes its projects — their effort is already
/// counted — so the project rows disable while the metric is selected, mirroring
/// the rollup's de-dup. The header count and the downstream totals recompute as
/// membership changes.
struct AspirationFeedPicker: View {
    @Query(sort: \Metric.createdAt) private var metrics: [Metric]
    @Binding var selectedMetrics: Set<Metric>
    @Binding var selectedProjects: Set<Project>
    let tint: Color
    /// The deeper variant of `tint` used behind white marks (see
    /// `MetricColor.prominentColor`), so selection badges stay readable.
    let prominentTint: Color

    @State private var expanded: Set<Metric> = []
    @State private var showingNewMetric = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            if metrics.isEmpty {
                emptyState
            } else {
                ForEach(metrics) { metric in
                    card(for: metric)
                }
                footnote
            }
        }
        .sheet(isPresented: $showingNewMetric) {
            MetricFormView()
        }
    }
}

// MARK: - Header & chrome

extension AspirationFeedPicker {
    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            FormEyebrow(text: "What feeds this · \(feedCount)", tint: tint)
            Spacer()
            Button { showingNewMetric = true } label: {
                Label("Add", systemImage: "plus")
                    .font(.caption.weight(.semibold))
            }
            .tint(tint)
        }
    }

    private var emptyState: some View {
        Text("No metrics yet. Add one to start feeding this aspiration.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
    }

    private var footnote: some View {
        Text("Tap a row to expand and pick individual projects. Totals recompute live as membership changes.")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Attachments after de-dup: every selected metric, plus the projects whose
    /// parent metric is not itself selected (the rollup counts those once).
    private var feedCount: Int {
        let standalone = selectedProjects.filter { project in
            guard let parent = project.metric else { return true }
            return !selectedMetrics.contains(parent)
        }
        return selectedMetrics.count + standalone.count
    }
}

// MARK: - Metric card

extension AspirationFeedPicker {
    private func card(for metric: Metric) -> some View {
        VStack(spacing: 0) {
            row(for: metric)
            if expanded.contains(metric) {
                projectList(for: metric)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.cardBackground)
        )
    }

    private func row(for metric: Metric) -> some View {
        HStack(spacing: 12) {
            Button { primaryTap(metric) } label: { rowLabel(metric) }
                .buttonStyle(.plain)
            Button { toggleWhole(metric) } label: {
                SelectionBadge(isSelected: selectedMetrics.contains(metric), tint: prominentTint)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Include \(metric.name)")
            .accessibilityAddTraits(selectedMetrics.contains(metric) ? .isSelected : [])
        }
        .padding(14)
    }

    private func rowLabel(_ metric: Metric) -> some View {
        HStack(spacing: 12) {
            iconChip(metric)
            VStack(alignment: .leading, spacing: 2) {
                Text(metric.name)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                Text(subtitle(for: metric))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            if hasProjects(metric) {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .rotationEffect(.degrees(expanded.contains(metric) ? 90 : 0))
            }
        }
        .contentShape(Rectangle())
    }

    private func iconChip(_ metric: Metric) -> some View {
        Image(systemName: metric.displayIcon)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .frame(width: 38, height: 38)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(metric.prominentColor)
            )
    }
}

// MARK: - Project rows

extension AspirationFeedPicker {
    private func projectList(for metric: Metric) -> some View {
        VStack(spacing: 0) {
            Divider().padding(.leading, 14)
            ForEach(sortedProjects(of: metric)) { project in
                projectRow(project, whole: selectedMetrics.contains(metric))
            }
        }
    }

    private func projectRow(_ project: Project, whole: Bool) -> some View {
        Button { toggleProject(project) } label: {
            HStack(spacing: 12) {
                Text(project.name)
                    .font(.subheadline)
                    .foregroundStyle(whole ? .secondary : .primary)
                Spacer(minLength: 4)
                SelectionBadge(
                    isSelected: whole || selectedProjects.contains(project),
                    tint: prominentTint,
                    size: 22
                )
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .padding(.leading, 38)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(whole)
        .accessibilityLabel("Include \(project.name)")
        .accessibilityAddTraits(whole || selectedProjects.contains(project) ? .isSelected : [])
    }
}

// MARK: - Subtitles & selection

extension AspirationFeedPicker {
    private func subtitle(for metric: Metric) -> String {
        if selectedMetrics.contains(metric) {
            return "Whole metric · \(structureLabel(metric))"
        }
        let picked = pickedCount(metric)
        if picked > 0 {
            return "\(picked) of \(metric.projects.count) projects"
        }
        return structureLabel(metric)
    }

    private func structureLabel(_ metric: Metric) -> String {
        let count = metric.projects.count
        if count > 0 {
            return "\(count) project\(count == 1 ? "" : "s")"
        }
        return metric.measurementType == .duration ? "timer" : "counter"
    }

    private func pickedCount(_ metric: Metric) -> Int {
        metric.projects.filter { selectedProjects.contains($0) }.count
    }

    private func hasProjects(_ metric: Metric) -> Bool {
        !metric.projects.isEmpty
    }

    private func sortedProjects(of metric: Metric) -> [Project] {
        metric.projects.sorted { $0.startedAt < $1.startedAt }
    }

    private func primaryTap(_ metric: Metric) {
        if hasProjects(metric) {
            withAnimation(.snappy) { toggleExpanded(metric) }
        } else {
            toggleWhole(metric)
        }
    }

    private func toggleExpanded(_ metric: Metric) {
        if expanded.contains(metric) {
            expanded.remove(metric)
        } else {
            expanded.insert(metric)
        }
    }

    private func toggleWhole(_ metric: Metric) {
        if selectedMetrics.contains(metric) {
            selectedMetrics.remove(metric)
        } else {
            selectedMetrics.insert(metric)
        }
    }

    private func toggleProject(_ project: Project) {
        if selectedProjects.contains(project) {
            selectedProjects.remove(project)
        } else {
            selectedProjects.insert(project)
        }
    }
}
