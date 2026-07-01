import SwiftData
import SwiftUI

/// The aspiration detail: a cover header, the "why" text, the live rollup
/// (lifetime + recent), and the editable list of attached metrics and projects,
/// each tappable through to its own screen. Edit sits in the toolbar; delete
/// hides behind the ellipsis menu and a confirmation, so the destructive
/// action is never one accidental tap away.
struct AspirationDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let aspiration: Aspiration
    @State private var showingEdit = false
    @State private var showingAttach = false
    @State private var showingDeleteConfirmation = false

    var body: some View {
        List {
            coverSection
            whySection
            effortSection(AspirationRollup.compute(for: aspiration))
            attachedSection
        }
        .navigationTitle(aspiration.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbar }
        .confirmationDialog(
            "Delete \(aspiration.title)?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Aspiration", role: .destructive, action: deleteAspiration)
        } message: {
            Text("Its metrics and projects stay in your library.")
        }
        .sheet(isPresented: $showingEdit) {
            AspirationFormView(aspiration: aspiration)
        }
        .sheet(isPresented: $showingAttach) {
            AspirationAttachSheet(aspiration: aspiration)
        }
    }
}

// MARK: - Sections

extension AspirationDetailView {
    private var coverSection: some View {
        Section {
            AspirationCoverBanner(aspiration: aspiration)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
        }
    }

    @ViewBuilder
    private var whySection: some View {
        if !aspiration.detail.isEmpty {
            Section {
                Text(aspiration.detail)
            }
        }
    }

    @ViewBuilder
    private func effortSection(_ rollup: AspirationRollup) -> some View {
        if rollup.attachmentCount == 0 {
            Section {
                Text("Nothing attached yet — add metrics or projects below.")
                    .foregroundStyle(.secondary)
            }
        } else {
            Section("Effort") {
                if rollup.hasData {
                    AspirationRollupHeader(rollup: rollup)
                } else {
                    Text("Nothing logged yet")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var attachedSection: some View {
        Section("Attached") {
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
    }
}

// MARK: - Rows

extension AspirationDetailView {
    private var sortedMetrics: [Metric] {
        aspiration.metrics.sorted { $0.createdAt < $1.createdAt }
    }

    private var sortedProjects: [Project] {
        aspiration.projects.sorted { $0.startedAt < $1.startedAt }
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

// MARK: - Toolbar & actions

extension AspirationDetailView {
    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem {
            Button("Edit") { showingEdit = true }
        }
        ToolbarItem {
            Menu {
                Button("Delete Aspiration", systemImage: "trash", role: .destructive) {
                    showingDeleteConfirmation = true
                }
            } label: {
                Label("More", systemImage: "ellipsis.circle")
            }
        }
    }

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

    private func deleteAspiration() {
        modelContext.delete(aspiration)
        dismiss()
    }
}
