import SwiftUI

struct VaultConflictsSection: View {
    let service: ObsidianSyncService

    var body: some View {
        if !service.conflicts.isEmpty {
            Section {
                ForEach(service.conflicts) { conflict in
                    VaultConflictRow(
                        conflict: conflict, choice: service.resolutions[conflict.id]?.choice, service: service
                    )
                }
                Button("Sync with These Choices") { service.syncNow() }
                    .disabled(service.unresolvedCount != 0 || service.isSyncing)
            } header: {
                Text("Resolve Conflicting Edits")
            } footer: {
                Text("Neither version has been discarded. Choose which value to keep for each conflict. "
                    +
                    "Your choices are checked against the latest files before syncing; newer edits may need a new choice.")
            }
        }
    }
}

private struct VaultConflictRow: View {
    let conflict: VaultConflict
    let choice: VaultResolution.Choice?
    let service: ObsidianSyncService

    var body: some View {
        DisclosureGroup(conflict.label) {
            VaultConflictVersion(title: "On this device", content: conflict.local)
            Button(choice == .local ? "Selected: Keep Device Version" : "Keep Device Version") {
                service.choose(.local, for: conflict)
            }
            .disabled(service.isSyncing)
            VaultConflictVersion(title: "In GitHub / Obsidian", content: conflict.remote)
            Button(choice == .remote ? "Selected: Keep Obsidian Version" : "Keep Obsidian Version") {
                service.choose(.remote, for: conflict)
            }
            .disabled(service.isSyncing)
        }
    }
}

private struct VaultConflictVersion: View {
    let title: String
    let content: VaultConflictContent?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            Text(content?.summary ?? "Deleted")
                .font(.body)
                .textSelection(.enabled)
        }
        .padding(.vertical, 4)
    }
}
