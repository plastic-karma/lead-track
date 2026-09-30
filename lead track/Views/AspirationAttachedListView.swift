import SwiftData
import SwiftUI

/// Behind the detail's "Attached" disclosure row: the aspiration's editable
/// membership — every attached metric and project, each tappable through to
/// its own screen, swipe-detachable (detaching only severs the link; the item
/// and its sessions survive), with the attach sheet behind the add row.
struct AspirationAttachedListView: View {
    let aspiration: Aspiration
    @State private var showingAttach = false

    var body: some View {
        List {
            ForEach(sortedMetrics) { metric in
                AspirationAttachedMetricRow(metric: metric)
            }
            .onDelete(perform: detachMetrics)
            ForEach(sortedProjects) { project in
                AspirationAttachedProjectRow(project: project, attachedMetrics: aspiration.metrics)
            }
            .onDelete(perform: detachProjects)
            Button { showingAttach = true } label: {
                Label("Add metric or project", systemImage: "plus.circle")
            }
        }
        .navigationTitle("Attached")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAttach) {
            AspirationAttachSheet(aspiration: aspiration)
        }
    }
}

// MARK: - Rows

extension AspirationAttachedListView {
    private var sortedMetrics: [Metric] {
        aspiration.metrics.inDisplayOrder
    }

    private var sortedProjects: [Project] {
        aspiration.projects.inDisplayOrder
    }
}

// MARK: - Detach

extension AspirationAttachedListView {
    private func detachMetrics(_ offsets: IndexSet) {
        let targets = offsets.map { sortedMetrics[$0] }
        withAnimation {
            for metric in targets {
                aspiration.metrics.removeAll { $0 === metric }
            }
        }
    }

    private func detachProjects(_ offsets: IndexSet) {
        let targets = offsets.map { sortedProjects[$0] }
        withAnimation {
            for project in targets {
                aspiration.projects.removeAll { $0 === project }
            }
        }
    }
}

private struct AspirationAttachedMetricRow: View {
    let metric: Metric

    var body: some View {
        NavigationLink(value: metric) {
            AspirationAttachmentLabel(
                name: metric.name, icon: metric.displayIcon, tint: metric.displayColor,
                detail: AspirationRollup.itemSummary(for: metric) ?? "Nothing logged yet"
            )
        }
    }
}

private struct AspirationAttachedProjectRow: View {
    let project: Project
    let attachedMetrics: [Metric]

    var body: some View {
        NavigationLink(value: project) {
            AspirationAttachmentLabel(
                name: project.name, icon: "folder",
                tint: MetricColor.color(named: project.metric?.colorName), detail: detail
            )
        }
    }

    private var detail: String {
        if let metric = project.metric, attachedMetrics.contains(where: { $0 === metric }) {
            return "Included in \(metric.name)"
        }
        return AspirationRollup.itemSummary(for: project) ?? "Nothing logged yet"
    }
}

private struct AspirationAttachmentLabel: View {
    let name: String
    let icon: String
    let tint: Color
    let detail: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(tint)
                .frame(width: 24)
            Text(name)
            Spacer()
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
