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
    private var lastPushed: WatchSnapshot?
    /// When the phone last spent a complication transfer to wake the watch,
    /// so bursts of saves coalesce into one wake (see `WatchComplicationPush`).
    private var lastComplicationWakeAt: Date?

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
        let context = WatchSyncCodec.context(for: snapshot)
        push(snapshot, encodedAs: context)
        return context
    }

    private func applyAction(from message: [String: Any]) {
        guard let container,
              let action = WatchSyncCodec.action(from: message)
        else { return }
        try? WatchActionHandler.apply(action, in: ModelContext(container))
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Outgoing

    private func currentSnapshot() -> WatchSnapshot? {
        guard let container else { return nil }
        return WatchSnapshotBuilder.snapshot(in: ModelContext(container))
    }

    /// Updates the watch's application context, skipping the transfer when
    /// the watch already holds identical state.
    private func push(
        _ snapshot: WatchSnapshot,
        encodedAs encoded: [String: Any]? = nil
    ) {
        let session = WCSession.default
        guard session.activationState == .activated,
              session.isPaired,
              session.isWatchAppInstalled,
              snapshot != lastPushed
        else { return }
        let context = encoded ?? WatchSyncCodec.context(for: snapshot)
        do {
            try session.updateApplicationContext(context)
            lastPushed = snapshot
            wakeComplication(session: session, encoded: context)
        } catch {
            // Leave lastPushed stale so the next change retries the transfer.
        }
    }

    /// Wakes the watch in the background so its complications reload without the
    /// app being opened — the one delivery that reaches a suspended watch.
    /// Budget- and rate-gated by `WatchComplicationPush`; degrades silently to
    /// the application-context push above when a complication isn't on the
    /// active face or the day's transfer budget is spent.
    private func wakeComplication(session: WCSession, encoded: [String: Any]) {
        let secondsSinceLastWake = lastComplicationWakeAt.map { Date.now.timeIntervalSince($0) } ?? .infinity
        let wake = WatchComplicationPush.shouldWake(
            complicationEnabled: session.isComplicationEnabled,
            remainingTransfers: session.remainingComplicationUserInfoTransfers,
            secondsSinceLastWake: secondsSinceLastWake,
            minInterval: WatchComplicationPush.minWakeInterval
        )
        guard wake else { return }
        session.transferCurrentComplicationUserInfo(encoded)
        lastComplicationWakeAt = .now
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
            // A complication just added to the face (or a freshly installed
            // watch app) needs the current state pushed and its timelines
            // woken, even when the snapshot itself hasn't changed.
            lastPushed = nil
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
