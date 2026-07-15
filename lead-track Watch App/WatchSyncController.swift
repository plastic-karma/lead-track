import Foundation
import Observation
import WatchConnectivity
import WidgetKit

/// Bridges the watch UI to the phone over WatchConnectivity. Keeps the last
/// snapshot cached locally, applies actions optimistically, and falls back to
/// queued delivery when the phone is unreachable.
@Observable
final class WatchSyncController: NSObject {
    /// One instance shared by the SwiftUI scene and the app delegate, so the
    /// session the delegate activates on a background launch is the same one
    /// the UI observes.
    static let shared = WatchSyncController()

    private(set) var snapshot: WatchSnapshot

    override init() {
        snapshot = WatchSnapshotCache.load()
        super.init()
    }

    func activate() {
        let session = WCSession.default
        session.delegate = self
        guard session.activationState == .notActivated else { return }
        session.activate()
    }

    func requestRefresh() {
        send(WatchSyncCodec.refreshRequest)
    }

    func perform(_ action: WatchAction) {
        update(to: WatchSnapshotReducer.applying(action, to: snapshot))
        let message = WatchSyncCodec.message(for: action)
        send(message) {
            WCSession.default.transferUserInfo(message)
        }
    }

    /// Sends a message while the phone is reachable, applying the snapshot
    /// that comes back in the reply. When it isn't — or sending fails —
    /// `fallback` runs instead (queued delivery for actions, nothing for
    /// refresh requests).
    private func send(
        _ message: [String: Any],
        fallback: (() -> Void)? = nil
    ) {
        let session = WCSession.default
        guard session.activationState == .activated, session.isReachable else {
            fallback?()
            return
        }
        let errorHandler: ((Error) -> Void)? = fallback.map { handler in
            { _ in handler() }
        }
        session.sendMessage(
            message,
            replyHandler: { [weak self] reply in
                Task { @MainActor in
                    self?.receive(context: reply)
                }
            },
            errorHandler: errorHandler
        )
    }

    private func receive(context: [String: Any]) {
        guard let snapshot = WatchSyncCodec.snapshot(from: context)
        else { return }
        update(to: snapshot)
    }

    private func update(to snapshot: WatchSnapshot) {
        guard snapshot != self.snapshot else { return }
        self.snapshot = snapshot
        WatchSnapshotCache.save(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
    }
}

// MARK: - WCSessionDelegate

extension WatchSyncController: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        guard activationState == .activated else { return }
        let context = session.receivedApplicationContext
        Task { @MainActor in
            receive(context: context)
            requestRefresh()
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        Task { @MainActor in
            receive(context: applicationContext)
        }
    }

    /// A complication push (`transferCurrentComplicationUserInfo`) arrives here,
    /// waking the app in the background. Applying the snapshot saves the cache
    /// and reloads the widget timelines, so the complications refresh even
    /// though the app was never opened.
    nonisolated func session(
        _ session: WCSession,
        didReceiveUserInfo userInfo: [String: Any] = [:]
    ) {
        Task { @MainActor in
            receive(context: userInfo)
        }
    }
}
