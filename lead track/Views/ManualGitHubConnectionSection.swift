import SwiftUI

struct ManualGitHubConnectionSection: View {
    @Binding var destination: VaultConfiguration
    @Binding var confirmingConnection: Bool
    let connect: @MainActor (VaultConfiguration, GitHubCredential) -> Bool
    @State private var token = ""
    @State private var isExpanded = false
    @State private var pending: Consent?
    @State private var errorMessage: String?

    private struct Consent: Equatable {
        let id = UUID()
        let destination: VaultConfiguration
    }

    var body: some View {
        Section {
            DisclosureGroup("Use a Manual Token Instead", isExpanded: $isExpanded) {
                ManualGitHubTokenFields(token: $token, requestConsent: requestConsent)
                    .disabled(confirmingConnection)
                if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
            }
        } footer: {
            Text("Optional: create a fine-grained token with Contents: Read and write for just this repository. "
                + "The token stays in this device’s Keychain.")
        }
        .confirmationDialog("Enable two-way GitHub sync?", isPresented: $confirmingConnection, presenting: pending) {
            consent in
            Button("Enable Sync") { enableSync(consent) }
            Button("Cancel", role: .cancel) { pending = nil }
        } message: { _ in
            GitHubSyncPrivacyNotice()
        }
        .onChange(of: confirmingConnection) { _, presented in if !presented { pending = nil } }
        .onDisappear {
            pending = nil
            token = ""
            confirmingConnection = false
        }
    }

    private func requestConsent() {
        guard pending == nil, !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        do {
            let validated = try destination.validated()
            destination = validated
            pending = Consent(destination: validated)
            errorMessage = nil
            confirmingConnection = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func enableSync(_ consent: Consent) {
        guard pending == consent else { return }
        pending = nil
        let credential = GitHubCredential(accessToken: token.trimmingCharacters(in: .whitespacesAndNewlines))
        token = ""
        _ = connect(consent.destination, credential)
    }
}

private struct ManualGitHubTokenFields: View {
    @Binding var token: String
    let requestConsent: () -> Void

    var body: some View {
        SecureField("Fine-grained access token", text: $token)
            .textContentType(.password)
            .privacySensitive()
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
        Link(
            "Create a GitHub token",
            destination: URL(string: "https://github.com/settings/personal-access-tokens/new")!
        )
        Button("Connect with Token", action: requestConsent)
            .disabled(token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }
}
