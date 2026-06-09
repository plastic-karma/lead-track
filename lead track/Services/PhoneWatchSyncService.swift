import Foundation
import SwiftData
import WatchConnectivity
import WidgetKit

/// Phone-side WatchConnectivity endpoint. Receives recording actions from the
/// watch, applies them to the shared store, and keeps the watch's snapshot of
/// metrics and running timers up to date.
final class PhoneWatchSyncService: NSObject {
    static let shared = PhoneWatchSyncService()

    private var container: ModelContainer?
    private var saveObserver: (any NSObjectProtocol)?

    func activate(container: ModelContainer) {
        guard WCSession.isSupported() else { return }
        self.container = container
        let session = WCSession.default
        session.delegate = self
        if session.activationState == .notActivated {
            session.activate()
        }
        observeSaves()
    }

    func pushSnapshot() {
        guard let snapshot = currentSnapshot() else { return }
        push(snapshot)
    }

    // MARK: - Incoming

    private func handle(message: [String: Any]) -> [String: Any] {
        applyAction(from: message)
        guard let snapshot = currentSnapshot() else { return [:] }
        push(snapshot)
        return WatchSyncCodec.context(for: snapshot)
    }

    private func applyAction(from message: [String: Any]) {
        guard let container,
              let action = WatchSyncCodec.action(from: message)
        else { return }
        try? WatchActionHandler.apply(action, in: container.mainContext)
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Outgoing

    private func currentSnapshot() -> WatchSnapshot? {
        guard let container else { return nil }
        return WatchSnapshotBuilder.snapshot(in: container.mainContext)
    }

    private func push(_ snapshot: WatchSnapshot) {
        let session = WCSession.default
        guard session.activationState == .activated,
              session.isPaired,
              session.isWatchAppInstalled
        else { return }
        try? session.updateApplicationContext(
            WatchSyncCodec.context(for: snapshot)
        )
    }

    private func observeSaves() {
        guard saveObserver == nil else { return }
        saveObserver = NotificationCenter.default.addObserver(
            forName: ModelContext.didSave,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.pushSnapshot()
            }
        }
    }
}

// MARK: - WCSessionDelegate

extension PhoneWatchSyncService: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        guard activationState == .activated else { return }
        Task { @MainActor in
            pushSnapshot()
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor in
            pushSnapshot()
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        Task { @MainActor in
            replyHandler(handle(message: message))
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveUserInfo userInfo: [String: Any] = [:]
    ) {
        Task { @MainActor in
            _ = handle(message: userInfo)
        }
    }
}
