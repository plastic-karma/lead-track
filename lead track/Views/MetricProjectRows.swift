import SwiftData
import SwiftUI

extension Metric {
    /// Active projects in the order the Projects fold lists them.
    var activeProjects: [Project] {
        projects
            .filter { $0.status == .active }
            .sorted { $0.startedAt < $1.startedAt }
    }

    /// Finished projects, most recently finished first.
    var finishedProjects: [Project] {
        projects
            .filter { $0.status == .finished }
            .sorted { ($0.finishedAt ?? .distantPast) > ($1.finishedAt ?? .distantPast) }
    }
}

/// One project inside the Projects fold: the name (dimmed and tagged once
/// finished), the default-project star, a recording pulse while one of its
/// timers runs, and the session count. Deleting hides behind a context menu —
/// the fold has no swipe actions to offer.
struct MetricProjectRow: View {
    @Environment(\.modelContext) private var modelContext
    let project: Project
    let tint: Color
    @State private var showingDeleteConfirmation = false
    @State private var deletionErrorMessage = ""
    @State private var showingDeletionError = false

    var body: some View {
        NavigationLink(value: project) {
            label
                .padding(.horizontal, 16)
                .frame(minHeight: 40)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Delete Project", systemImage: "trash", role: .destructive) {
                showingDeleteConfirmation = true
            }
        }
        .confirmationDialog(
            "Delete \(project.name)?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Project", role: .destructive, action: deleteProject)
        } message: {
            Text("Every session logged in this project is deleted with it. This can't be undone.")
        }
        .alert("Couldn't delete project", isPresented: $showingDeletionError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(deletionErrorMessage)
        }
    }

    private var label: some View {
        HStack(spacing: 5) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(project.status == .finished ? .secondary : .primary)
            if project.isDefault {
                Image(systemName: "star.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Default project")
            }
            Spacer()
            if project.sessions.contains(where: \.isRunning) {
                Image(systemName: "record.circle")
                    .foregroundStyle(tint)
                    .symbolEffect(.pulse)
            }
            Text(ValueFormatter.sessions(project.sessions.count))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var title: String {
        project.status == .finished ? "\(project.name) · finished" : project.name
    }

    private func deleteProject() {
        do {
            try withAnimation {
                try modelContext.deleteProjectAndDependents(project)
            }
        } catch {
            deletionErrorMessage = error.localizedDescription
            showingDeletionError = true
        }
    }
}
