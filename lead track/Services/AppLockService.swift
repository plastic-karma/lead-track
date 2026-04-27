import Foundation
import LocalAuthentication
import Observation
import SwiftUI

enum AppLockGracePeriod: Int, CaseIterable, Identifiable {
    case immediately = 0
    case oneMinute = 60
    case fiveMinutes = 300
    case untilNextLaunch = -1

    var id: Int {
        rawValue
    }

    var label: String {
        switch self {
        case .immediately: "Immediately"
        case .oneMinute: "After 1 minute"
        case .fiveMinutes: "After 5 minutes"
        case .untilNextLaunch: "Until next launch"
        }
    }
}

@MainActor
@Observable
final class AppLockService {
    static let enabledKey = "appLockEnabled"
    static let gracePeriodKey = "appLockGracePeriod"

    private(set) var isLocked: Bool
    private var backgroundedAt: Date?
    private let disabledForTest: Bool

    init() {
        let isUITest = ProcessInfo.processInfo.arguments.contains("-uitest")
        disabledForTest = isUITest
        let enabled = UserDefaults.standard.bool(forKey: Self.enabledKey)
        isLocked = !isUITest && enabled
    }

    var isEnabled: Bool {
        guard !disabledForTest else { return false }
        return UserDefaults.standard.bool(forKey: Self.enabledKey)
    }

    private var gracePeriod: AppLockGracePeriod {
        let raw = UserDefaults.standard.integer(forKey: Self.gracePeriodKey)
        return AppLockGracePeriod(rawValue: raw) ?? .immediately
    }

    func authenticate() async {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(
            .deviceOwnerAuthentication, error: &error
        ) else { return }
        do {
            try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: "Unlock LeadStone"
            )
            isLocked = false
            backgroundedAt = nil
        } catch {
            // User cancelled or failed; stay locked, can retry.
        }
    }

    func handleScenePhase(_ phase: ScenePhase) {
        guard isEnabled else { return }
        switch phase {
        case .background, .inactive:
            if backgroundedAt == nil { backgroundedAt = .now }
        case .active:
            applyLockIfNeeded()
        @unknown default:
            break
        }
    }

    private func applyLockIfNeeded() {
        guard let backgroundedAt else { return }
        switch gracePeriod {
        case .immediately:
            isLocked = true
        case .untilNextLaunch:
            break
        case .oneMinute, .fiveMinutes:
            let elapsed = Date.now.timeIntervalSince(backgroundedAt)
            if elapsed >= TimeInterval(gracePeriod.rawValue) {
                isLocked = true
            }
        }
        self.backgroundedAt = nil
    }
}
