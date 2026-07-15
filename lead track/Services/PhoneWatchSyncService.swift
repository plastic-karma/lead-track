import Foundation
import SwiftData
import WatchConnectivity
import WidgetKit

/// Phone-side WatchConnectivity endpoint. Receives recording actions from the
/// watch, applies them to the shared store, and keeps the watch's snapshot of
/// metrics and running timers up to date. Its store observer is also the one
/// hub that refreshes the home-screen widgets, so every denormalized copy is
/// invalidated by the same save.
final class PhoneWatchSyncService: NSObject {
    static let shared = PhoneWatchSyncService()

    private static let appliedIDsKey = "watchAppliedActionIDs"
    private static let appliedIDsCap = 64

    private var container: ModelContainer?
    private var saveObserver: (any NSObjectProtocol)?
    private var lastPushed: WatchSnapshot?
    private var propagation: Task<Void, Never>?
    /// Recently applied action IDs, oldest first. WatchConnectivity delivers
    /// at-least-once — a reply timeout re-queues a payload the phone already
    /// applied — so replays are dropped instead of double-applied (a replayed
    /// toggle would UN-do the day; a replayed log doubles the count).
    /// Persisted because queued transfers can arrive across relaunches.
    private lazy var appliedActionIDs: [UUID] = Self.loadAppliedIDs()

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
        // Pairing is checked before the snapshot is built, so iPhone-only
        // users never pay a store scan for a watch they don't have.
        guard watchAppReachable else { return }
        guard let snapshot = currentSnapshot() else { return }
        push(snapshot)
    }

    // MARK: - Incoming

    private func handle(message: [String: Any]) -> [String: Any] {
        applyAction(from: message)
        guard let snapshot = currentSnapshot(),
              let context = WatchSyncCodec.context(for: snapshot)
        else { return [:] }
        push(snapshot, encodedAs: context)
        return context
    }

    private func applyAction(from message: [String: Any]) {
        guard let container,
              let action = WatchSyncCodec.action(from: message)
        else { return }
        if let id = action.id, appliedActionIDs.contains(id) {
            SyncLog.notice("Dropped replayed watch action \(id)")
            return
        }
        do {
            try WatchActionHandler.apply(action, in: ModelContext(container))
            if let id = action.id { markApplied(id) }
        } catch {
            // WCSession consumes a queued transfer exactly once, so a
            // swallowed throw here would silently lose a wrist recording.
            SyncLog.error(
                "Applying watch action \(action.kind.rawValue) for metric \(action.metricID) failed: \(error)"
            )
        }
    }

    // MARK: - Outgoing

    private var watchAppReachable: Bool {
        let session = WCSession.default
        return session.activationState == .activated
            && session.isPaired
            && session.isWatchAppInstalled
    }

    private func currentSnapshot() -> WatchSnapshot? {
        guard let container else { return nil }
        return WatchSnapshotBuilder.snapshot(in: ModelContext(container))
    }

    /// Updates the watch's application context, skipping the transfer when
    /// the watch already holds identical content.
    private func push(
        _ snapshot: WatchSnapshot,
        encodedAs encoded: [String: Any]? = nil
    ) {
        guard watchAppReachable else { return }
        if let lastPushed, snapshot.hasSameContent(as: lastPushed) { return }
        guard let payload = encoded ?? WatchSyncCodec.context(for: snapshot)
        else { return }
        do {
            try WCSession.default.updateApplicationContext(payload)
            lastPushed = snapshot
        } catch {
            // Leave lastPushed stale so the next change retries the transfer.
            SyncLog.error("Application-context push failed: \(error)")
        }
    }

    private func observeSaves() {
        guard saveObserver == nil else { return }
        saveObserver = NotificationCenter.default.addObserver(
            forName: ModelContext.didSave,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.schedulePropagation()
            }
        }
    }

    /// Debounced fan-out of a store change to every denormalized copy: the
    /// home-screen widget timelines and the watch snapshot. Coalescing keeps
    /// burst saves (a Health sync pass) from rebuilding once per save.
    private func schedulePropagation() {
        propagation?.cancel()
        propagation = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(250))
            } catch {
                return // superseded by a newer save
            }
            WidgetCenter.shared.reloadAllTimelines()
            self?.pushSnapshot()
        }
    }

    private static func loadAppliedIDs() -> [UUID] {
        let stored = UserDefaults.standard.stringArray(forKey: appliedIDsKey) ?? []
        return stored.compactMap(UUID.init(uuidString:))
    }

    private func markApplied(_ id: UUID) {
        appliedActionIDs.append(id)
        appliedActionIDs = Array(appliedActionIDs.suffix(Self.appliedIDsCap))
        UserDefaults.standard.set(
            appliedActionIDs.map(\.uuidString),
            forKey: Self.appliedIDsKey
        )
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
