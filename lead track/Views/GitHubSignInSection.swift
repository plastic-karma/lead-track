import SwiftUI
import UIKit

struct GitHubSignInSection: View {
    let model: GitHubSignInModel
    @Binding var destination: VaultConfiguration
    let isDisabled: Bool
    let connect: @MainActor @Sendable (VaultConfiguration, GitHubCredential) -> Bool
    @State private var confirmingConnection = false
    @State private var consentID: UUID?

    var body: some View {
        Section {
            GitHubSignInProgress(model: model, isDisabled: isDisabled, signIn: requestConsent)
            if let message = model.errorMessage {
                Text(message).foregroundStyle(.red)
            }
        } header: {
            Text("Sign in with GitHub")
        } footer: {
            Text("GitHub sign-in requests the broader repo permission, which can cover multiple repositories. "
                + "LeadStone syncs only the destination above. For repository-only access, use a fine-grained "
                + "token below. Credentials stay in this device’s Keychain, never in your vault.")
        }
        .confirmationDialog("Enable two-way GitHub sync?", isPresented: $confirmingConnection, presenting: consentID) {
            identity in
            Button("Agree & Continue to GitHub") {
                model.authorize(consentFor: identity) { configuration, credential in
                    connect(configuration, credential)
                }
            }
            Button("Cancel", role: .cancel) { model.cancel() }
        } message: { _ in
            GitHubSyncPrivacyNotice()
        }
        .onChange(of: confirmingConnection) { _, presented in
            if !presented, model.state == .awaitingConsent { model.cancel() }
        }
    }

    private func requestConsent() {
        guard !isDisabled, let identity = model.prepare(configuration: destination) else { return }
        if let validated = model.destination { destination = validated }
        consentID = identity
        confirmingConnection = true
    }
}

private struct GitHubSignInProgress: View {
    let model: GitHubSignInModel
    let isDisabled: Bool
    let signIn: () -> Void

    var body: some View {
        if let code = model.code {
            GitHubDeviceApprovalView(code: code, cancel: model.cancel)
        } else if model.state == .starting {
            ProgressView("Requesting a GitHub code…")
            Button("Cancel Sign-In", role: .cancel, action: model.cancel)
        } else {
            Button("Continue with GitHub", systemImage: "person.crop.circle.badge.checkmark", action: signIn)
                .buttonStyle(.borderedProminent)
                .disabled(isDisabled || model.isInFlight || !model.isAvailable)
            if !model.isAvailable {
                Text("GitHub sign-in is not configured in this build. You can still connect with a manual token below.")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct GitHubDeviceApprovalView: View {
    let code: GitHubSignInModel.Code
    let cancel: () -> Void
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("GitHub verification code").font(.headline)
            Text(verbatim: code.userCode)
                .font(.largeTitle.monospaced().weight(.semibold))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
                .privacySensitive()
                .accessibilityLabel("GitHub verification code")
                .accessibilityValue(code.userCode)
            Text("Enter this code at github.com/login/device on another device, or open GitHub below.")
                .font(.subheadline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
        Button(copied ? "Code Copied" : "Copy Code", systemImage: copied ? "checkmark" : "doc.on.doc") {
            UIPasteboard.general.setItems([["public.utf8-plain-text": code.userCode]], options: [
                .localOnly: true, .expirationDate: code.expiresAt
            ])
            copied = true
        }
        .buttonStyle(.borderless)
        Link("Open GitHub", destination: code.verificationURL)
            .buttonStyle(.borderedProminent)
        VStack(alignment: .leading, spacing: 8) {
            ProgressView("Waiting for GitHub approval…")
            Text("Code expires \(code.expiresAt, format: .dateTime.hour().minute()). Return here after approving.")
                .font(.caption).foregroundStyle(.secondary)
        }
        Button("Cancel Sign-In", role: .cancel, action: cancel)
            .buttonStyle(.borderless)
    }
}

struct GitHubSyncPrivacyNotice: View {
    var body: some View {
        Text("After authorization, sync uploads saved notes, measurements (including Health-linked values), photos "
            + "and locations. Anyone with repository access can read them. Edits and deletions sync both ways; "
            + "Git history retains previous content. Use a private repository for personal data.")
    }
}
