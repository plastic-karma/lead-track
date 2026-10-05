import SwiftUI

struct ObsidianSyncSettingsView: View {
    let service: ObsidianSyncService
    @State private var destination = VaultConfiguration(owner: "", repository: "", branch: "main", folder: "LeadStone")
    @State private var signIn: GitHubSignInModel?
    @State private var confirmingManualConnection = false

    var body: some View {
        Form {
            VaultSyncStatusSection(service: service)
            VaultConnectionFields(destination: $destination)
                .disabled(service.isEnabled || service.isSyncing || connectionInProgress)
            if service.isEnabled {
                VaultSyncActionsSection(service: service)
                VaultConflictsSection(service: service)
            } else if let signIn {
                GitHubSignInSection(
                    model: signIn, destination: $destination,
                    isDisabled: service.isSyncing || confirmingManualConnection, connect: connect
                )
                ManualGitHubConnectionSection(
                    destination: $destination, confirmingConnection: $confirmingManualConnection, connect: connect
                )
                .disabled(service.isSyncing || signIn.isInFlight)
            }
        }
        .navigationTitle("Obsidian & GitHub")
        .task { prepareSettings() }
        .onChange(of: service.isEnabled) { _, enabled in if enabled { signIn?.cancel() } }
        .onDisappear { signIn?.cancel() }
    }

    private var connectionInProgress: Bool {
        signIn?.isInFlight == true || confirmingManualConnection
    }

    private func prepareSettings() {
        if let saved = service.configuration { destination = saved }
        if signIn == nil {
            let clientID = GitHubOAuthConfiguration.clientID
            signIn = GitHubSignInModel(authorizer: clientID.isEmpty ? nil : GitHubDeviceOAuth(clientID: clientID))
        }
    }

    private func connect(configuration: VaultConfiguration, credential: GitHubCredential) -> Bool {
        guard !service.isEnabled, !service.isSyncing else { return false }
        return service.connect(configuration: configuration, credential: credential)
    }
}

private struct VaultConnectionFields: View {
    @Binding var destination: VaultConfiguration

    var body: some View {
        Section {
            TextField("GitHub owner", text: $destination.owner)
            TextField("Repository", text: $destination.repository)
            TextField("Branch", text: $destination.branch)
            TextField("Vault subdirectory", text: $destination.folder)
        } header: {
            Text("Vault Connection")
        } footer: {
            Text("Choose an existing repository and branch, and a nonempty folder inside your vault, such as "
                + "LeadStone. The folder may be created by the first sync. First sync merges local records with "
                + "this folder; it does not replace either side.")
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
