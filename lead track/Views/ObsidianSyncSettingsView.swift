import SwiftUI

struct ObsidianSyncSettingsView: View {
    let service: ObsidianSyncService
    @State private var destination = VaultConfiguration(owner: "", repository: "", branch: "main", folder: "LeadStone")
    @State private var token = ""
    @State private var confirmingConnection = false

    var body: some View {
        Form {
            VaultSyncStatusSection(service: service)
            VaultConnectionFields(destination: $destination, token: $token, isConnected: service.isEnabled)
                .disabled(service.isEnabled || service.isSyncing)
            if service.isEnabled {
                VaultSyncActionsSection(service: service)
                VaultConflictsSection(service: service)
            } else {
                Section {
                    Button("Connect GitHub & Enable Sync") { confirmingConnection = true }
                        .disabled(token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                } footer: {
                    Text("First sync merges your local records with this folder; it does not replace either side.")
                }
            }
        }
        .navigationTitle("Obsidian & GitHub")
        .task { if let saved = service.configuration { destination = saved } }
        .onChange(of: service.isEnabled) { _, enabled in if enabled { token = "" } }
        .confirmationDialog("Enable two-way GitHub sync?", isPresented: $confirmingConnection) {
            Button("Enable Sync") { service.connect(configuration: destination, token: token) }
        } message: {
            Text("Your saved notes, measurements (including Health-linked values), photos and locations will be "
                + "uploaded. Anyone with repository access can read them. Edits and deletions sync both ways; "
                + "Git history retains previous content. Use a private repository for personal data.")
        }
    }
}

private struct VaultConnectionFields: View {
    @Binding var destination: VaultConfiguration
    @Binding var token: String
    let isConnected: Bool

    var body: some View {
        Section {
            TextField("GitHub owner", text: $destination.owner)
            TextField("Repository", text: $destination.repository)
            TextField("Branch", text: $destination.branch)
            TextField("Vault subdirectory", text: $destination.folder)
            if !isConnected {
                SecureField("Fine-grained access token", text: $token)
                    .textContentType(.password)
                    .privacySensitive()
                Link(
                    "Create a GitHub token",
                    destination: URL(string: "https://github.com/settings/personal-access-tokens/new")!
                )
            }
        } header: {
            Text("Vault Connection")
        } footer: {
            Text("Choose an existing repository and branch, and a nonempty folder inside your vault, such as "
                + "LeadStone. The folder may be created by the first sync. The token needs Contents: Read and write "
                + "for this repository only. It stays in this device’s Keychain.")
        }
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
    }
}

private struct VaultSyncStatusSection: View {
    let service: ObsidianSyncService

    var body: some View {
        Section {
            Label(service.isEnabled ? "Two-way sync enabled" : "Local only", systemImage: "externaldrive")
            if service.isSyncing {
                HStack {
                    ProgressView()
                    Text("Syncing with GitHub…")
                }
            }
            if let date = service.lastSyncedAt {
                LabeledContent("Last completed sync") { Text(date, format: .dateTime.month().day().hour().minute()) }
            }
            if let error = service.errorMessage {
                Text(error).foregroundStyle(.red).textSelection(.enabled)
            }
        } footer: {
            Text("LeadStone always works offline. When connected, it syncs when opened, after local saves, or "
                + "when you tap Sync Now. Changes made in Obsidian must be pushed to the selected GitHub branch first.")
        }
    }
}

private struct VaultSyncActionsSection: View {
    let service: ObsidianSyncService
    @State private var confirmingDisconnect = false

    var body: some View {
        Section {
            Button("Sync Now", systemImage: "arrow.triangle.2.circlepath") { service.syncNow() }
                .disabled(service.isSyncing)
            Button("Disconnect GitHub", role: .destructive) { confirmingDisconnect = true }
        } footer: {
            Text("Disconnecting stops sync and removes the token. Local records and repository files stay intact.")
        }
        .confirmationDialog("Disconnect GitHub?", isPresented: $confirmingDisconnect) {
            Button("Disconnect", role: .destructive) { Task { await service.disconnect() } }
        } message: {
            Text("Unsynced local changes stay on this device. Reconnect to resume syncing them.")
        }
    }
}
