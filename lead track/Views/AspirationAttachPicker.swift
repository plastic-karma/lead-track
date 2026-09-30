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
                AspirationAttachMetricSection(
                    metric: metric,
                    selectedMetrics: $selectedMetrics,
                    selectedProjects: $selectedProjects
                )
            }
        }
    }
}

private struct AspirationAttachMetricSection: View {
    let metric: Metric
    @Binding var selectedMetrics: Set<Metric>
    @Binding var selectedProjects: Set<Project>

    var body: some View {
        let metricSelected = selectedMetrics.contains(metric)
        Section(metric.name) {
            Toggle("Whole metric", isOn: $selectedMetrics[selected: metric])
            ForEach(metric.projects.inDisplayOrder) { project in
                Toggle(isOn: $selectedProjects[selected: project]) {
                    Text(project.name)
                        .foregroundStyle(metricSelected ? .secondary : .primary)
                }
                .disabled(metricSelected)
            }
        }
    }
}
