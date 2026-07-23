import LocalAuthentication
import SwiftData
import SwiftUI
import UIKit

/// Principal controller for the custom Share Extension. The containing app is
/// not launched: iOS hosts this SwiftUI composer inside Photos, and both
/// processes meet only through the existing app-group SwiftData store.
final class ShareViewController: UIViewController {
    private var hostingController: UIViewController?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        guard let extensionContext else {
            embed(ShareUnavailableView(close: {}))
            return
        }
        if AppPrivacySettings.requiresAuthenticationForExtension() {
            authenticate(extensionContext)
        } else {
            presentComposer(extensionContext)
        }
    }

    private func authenticate(_ extensionContext: NSExtensionContext) {
        embed(ShareUnlockingView())
        Task { @MainActor in
            let authentication = LAContext()
            var authenticationError: NSError?
            guard authentication.canEvaluatePolicy(
                .deviceOwnerAuthentication,
                error: &authenticationError
            ) else {
                cancel(extensionContext, error: authenticationError)
                return
            }

            do {
                let authenticated = try await authentication.evaluatePolicy(
                    .deviceOwnerAuthentication,
                    localizedReason: "Unlock LeadStone to keep this moment"
                )
                guard authenticated else {
                    cancel(extensionContext)
                    return
                }
                presentComposer(extensionContext)
            } catch {
                cancel(extensionContext, error: error)
            }
        }
    }

    private func presentComposer(_ extensionContext: NSExtensionContext) {
        guard let container = SharedModelContainer.shared else {
            embed(ShareUnavailableView { [weak self] in
                self?.cancel(extensionContext)
            })
            return
        }
        embed(
            ShareMomentView(extensionContext: extensionContext)
                .modelContainer(container)
        )
    }

    private func embed<Content: View>(_ rootView: Content) {
        hostingController?.willMove(toParent: nil)
        hostingController?.view.removeFromSuperview()
        hostingController?.removeFromParent()

        let host = UIHostingController(rootView: rootView)
        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        host.didMove(toParent: self)
        hostingController = host
    }

    private func cancel(_ context: NSExtensionContext, error: Error? = nil) {
        context.cancelRequest(withError: error ?? CocoaError(.fileReadNoPermission))
    }
}

private struct ShareUnlockingView: View {
    var body: some View {
        ProgressView("Unlocking LeadStone…")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ShareUnavailableView: View {
    let close: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("LeadStone Is Unavailable", systemImage: "exclamationmark.triangle")
        } description: {
            Text("The shared library couldn't be opened. Open LeadStone and try again.")
        } actions: {
            Button("Close", action: close)
                .buttonStyle(.borderedProminent)
        }
    }
}
