import Foundation
import SwiftData
import WidgetKit

/// Stops countdown timers the instant they reach zero while the app is running,
/// and finalizes any that elapsed while it was away. The phone owns the store,
/// so this is the one place a countdown turns itself off on screen; the local
/// notification scheduled when it started covers the case where the app never
/// comes back.
@MainActor
final class CountdownCoordinator {
    static let shared = CountdownCoordinator()

    private var container: ModelContainer?
    private var saveObserver: (any NSObjectProtocol)?
    private var timer: Timer?

    func activate(container: ModelContainer) {
        self.container = container
        observeSaves()
        reconcile()
    }

    /// Finalizes elapsed countdowns now, then arms a wake for the next one.
    func reconcile() {
        guard let container else { return }
        let context = ModelContext(container)
        if SessionService.reconcileCountdowns(in: context) {
            try? context.save()
            WidgetCenter.shared.reloadAllTimelines()
        }
        arm(using: context)
    }

    private func arm(using context: ModelContext) {
        timer?.invalidate()
        guard let next = SessionService.nextCountdownEnd(in: context) else {
            timer = nil
            return
        }
        // A half-second past the end so the session has truly elapsed.
        let delay = max(next.timeIntervalSinceNow, 0) + 0.5
        timer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.reconcile() }
        }
    }

    private func observeSaves() {
        guard saveObserver == nil else { return }
        saveObserver = NotificationCenter.default.addObserver(
            forName: ModelContext.didSave,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.rearm() }
        }
    }

    /// A save may have started or stopped a timer; recompute the wake without
    /// reconciling, which would re-enter through its own save.
    private func rearm() {
        guard let container else { return }
        arm(using: ModelContext(container))
    }
}
