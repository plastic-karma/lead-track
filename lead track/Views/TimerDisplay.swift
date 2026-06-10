import SwiftUI

/// An inline elapsed-time readout for a recording session, tinted with the
/// metric's identity color — red stays reserved for destructive actions.
/// The stat-tier rounded monospaced digits keep it on the app's three-size
/// numeric scale.
struct TimerDisplay: View {
    let startedAt: Date
    var tint: Color = .accentColor

    var body: some View {
        Text(startedAt, style: .timer)
            .numeralStyle(.stat)
            .foregroundStyle(tint)
    }
}
