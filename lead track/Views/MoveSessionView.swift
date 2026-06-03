import SwiftData
import SwiftUI

struct MoveSessionView: View {
    let session: Session
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if session.project != nil {
                    topLevelSection
                }
                projectsSection
            }
            .navigationTitle("Move Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Sections

extension MoveSessionView {
    /// Other projects under the same metric, active ones first, that the
    /// session isn't already in.
    private var destinations: [Project] {
        let current = session.project?.persistentModelID
        return (session.metric?.projects ?? [])
            .filter { $0.persistentModelID != current }
            .sorted(by: orderedBefore)
    }

    private func orderedBefore(_ lhs: Project, _ rhs: Project) -> Bool {
        if lhs.status != rhs.status {
            return lhs.status == .active
        }
        return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
    }

    private var topLevelSection: some View {
        Section {
            Button {
                move(to: nil)
            } label: {
                Label("No Project (Top Level)", systemImage: "tray")
            }
        }
    }

    private var projectsSection: some View {
        Section("Projects") {
            if destinations.isEmpty {
                Text("No other projects")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(destinations) { project in
                    Button { move(to: project) } label: {
                        projectLabel(project)
                    }
                }
            }
        }
    }

    private func projectLabel(_ project: Project) -> some View {
        HStack {
            Text(project.name)
            Spacer()
            if project.status == .finished {
                Text("Finished")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func move(to project: Project?) {
        SessionService.move(session, to: project)
        dismiss()
    }
}
