import SwiftData
import SwiftUI

/// The attach editor, emitted as a set of `Section`s for a surrounding `Form`:
/// each metric can be attached as a whole, or expanded to pick individual
/// projects. Selecting a metric subsumes its projects — their effort is already
/// counted — so the project toggles disable while the metric is selected,
/// mirroring the rollup's de-dup. Used by the detail screen's "Add" sheet;
/// the create/edit form draws the card-style `AspirationFeedPicker`, which
/// implements the same selection rules.
struct AspirationAttachPicker: View {
    @Query(sort: \Metric.createdAt) private var metrics: [Metric]
    @Binding var selectedMetrics: Set<Metric>
    @Binding var selectedProjects: Set<Project>

    var body: some View {
        if metrics.isEmpty {
            Section {
                Text("Add metrics first to attach them to an aspiration.")
                    .foregroundStyle(.secondary)
            }
        } else {
            ForEach(metrics) { metric in
                section(for: metric)
            }
        }
    }
}

// MARK: - Rows

extension AspirationAttachPicker {
    private func section(for metric: Metric) -> some View {
        Section(metric.name) {
            Toggle("Whole metric", isOn: metricBinding(metric))
            ForEach(sortedProjects(of: metric)) { project in
                projectToggle(project, metricSelected: selectedMetrics.contains(metric))
            }
        }
    }

    private func projectToggle(_ project: Project, metricSelected: Bool) -> some View {
        Toggle(isOn: projectBinding(project)) {
            Text(project.name)
                .foregroundStyle(metricSelected ? .secondary : .primary)
        }
        .disabled(metricSelected)
    }

    private func sortedProjects(of metric: Metric) -> [Project] {
        metric.projects.inDisplayOrder
    }

    private func metricBinding(_ metric: Metric) -> Binding<Bool> {
        Binding(
            get: { selectedMetrics.contains(metric) },
            set: { isOn in
                if isOn { selectedMetrics.insert(metric) } else { selectedMetrics.remove(metric) }
            }
        )
    }

    private func projectBinding(_ project: Project) -> Binding<Bool> {
        Binding(
            get: { selectedProjects.contains(project) },
            set: { isOn in
                if isOn { selectedProjects.insert(project) } else { selectedProjects.remove(project) }
            }
        )
    }
}
