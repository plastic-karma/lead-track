import Foundation
import Testing
@testable import lead_track

struct WatchComplicationPushTests {
    private let interval: TimeInterval = 90

    private func shouldWake(
        enabled: Bool = true,
        budget: Int = 10,
        secondsSinceLastWake: TimeInterval = 120
    ) -> Bool {
        WatchComplicationPush.shouldWake(
            complicationEnabled: enabled,
            remainingTransfers: budget,
            secondsSinceLastWake: secondsSinceLastWake,
            minInterval: interval
        )
    }

    @Test
    func wakesWhenEnabledWithBudgetPastInterval() {
        #expect(shouldWake())
    }

    @Test
    func doesNotWakeWhenComplicationDisabled() {
        #expect(!shouldWake(enabled: false))
    }

    @Test
    func doesNotWakeWhenBudgetExhausted() {
        #expect(!shouldWake(budget: 0))
    }

    @Test
    func doesNotWakeWithinTheInterval() {
        #expect(!shouldWake(secondsSinceLastWake: 30))
    }

    @Test
    func wakesExactlyAtTheInterval() {
        #expect(shouldWake(secondsSinceLastWake: interval))
    }

    /// `.infinity` models "never woken before" — the first change must wake.
    @Test
    func firstEverChangeWakes() {
        #expect(shouldWake(budget: 1, secondsSinceLastWake: .infinity))
    }
}
