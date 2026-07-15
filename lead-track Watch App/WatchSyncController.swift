import Foundation
import Observation
import WatchConnectivity
import WidgetKit

/// Bridges the watch UI to the phone over WatchConnectivity. Keeps the last
/// snapshot cached locally, applies actions optimistically, and falls back to
/// queued delivery when the phone is unreachable.
@Observable
final class WatchSyncController: NSObject {
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
        guard let message = WatchSyncCodec.message(for: action) else { return }
        // A live message overtakes transfers still queued from an
        // unreachable stretch, and out-of-order delivery corrupts state (a
        // queued start arriving after a live stop strands a phantom running
        // timer). Stay in the queue until it has fully drained.
        if !WCSession.default.outstandingUserInfoTransfers.isEmpty {
            SyncLog.notice("Transfer queue busy; queueing action to keep FIFO order")
            WCSession.default.transferUserInfo(message)
            return
        }
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
        session.sendMessage(
            message,
            replyHandler: { [weak self] reply in
                Task { @MainActor in
                    self?.receive(context: reply)
                }
            },
            errorHandler: { error in
                // WCSession invokes this on a background queue; hop back so
                // the fallback runs on the same isolation as every other
                // delivery path.
                Task { @MainActor in
                    SyncLog.error("sendMessage failed, using queued fallback: \(error)")
                    fallback?()
                }
            }
        )
    }

    private func receive(context: [String: Any]) {
        guard let incoming = WatchSyncCodec.snapshot(from: context) else { return }
        guard WatchSnapshotReducer.shouldAccept(incoming, over: snapshot) else {
            SyncLog.notice("Ignored stale snapshot replay")
            return
        }
        update(to: replayingPendingActions(on: incoming))
    }

    /// Re-applies actions still waiting in the transfer queue on top of an
    /// accepted snapshot. The phone hasn't seen them yet, so its snapshot
    /// would otherwise roll back optimistic state — un-checking a habit the
    /// user just checked — until the queue drains.
    private func replayingPendingActions(on snapshot: WatchSnapshot) -> WatchSnapshot {
        WCSession.default.outstandingUserInfoTransfers
            .compactMap { WatchSyncCodec.action(from: $0.userInfo) }
            .reduce(snapshot) { WatchSnapshotReducer.applying($1, to: $0) }
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
}
