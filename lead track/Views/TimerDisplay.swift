import SwiftUI

/// An inline elapsed-time readout for a recording session. Red is the one
/// color reserved for "recording"; the stat-tier rounded monospaced digits
/// keep it on the app's three-size numeric scale.
struct TimerDisplay: View {
    let startedAt: Date

    var body: some View {
        Text(startedAt, style: .timer)
            .numeralStyle(.stat)
            .foregroundStyle(.red)
    }
}
