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
                metricRow(metric)
            }
            .onDelete(perform: detachMetrics)
            ForEach(sortedProjects) { project in
                projectRow(project)
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

    private func metricRow(_ metric: Metric) -> some View {
        NavigationLink(value: metric) {
            attachmentRow(
                name: metric.name,
                icon: metric.displayIcon,
                tint: metric.displayColor,
                detail: AspirationRollup.itemSummary(for: metric) ?? "Nothing logged yet"
            )
        }
    }

    private func projectRow(_ project: Project) -> some View {
        NavigationLink(value: project) {
            attachmentRow(
                name: project.name,
                icon: "folder",
                tint: MetricColor.color(named: project.metric?.colorName),
                detail: projectDetail(project)
            )
        }
    }

    private func attachmentRow(
        name: String,
        icon: String,
        tint: Color,
        detail: String
    ) -> some View {
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

    /// A project whose parent metric is also attached is folded into that metric
    /// for totals, so its row says so instead of repeating the effort.
    private func projectDetail(_ project: Project) -> String {
        if let metric = project.metric, aspiration.metrics.contains(where: { $0 === metric }) {
            return "Included in \(metric.name)"
        }
        return AspirationRollup.itemSummary(for: project) ?? "Nothing logged yet"
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
