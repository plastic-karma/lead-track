import SwiftUI

struct TimerDisplay: View {
    let startedAt: Date

    var body: some View {
        Text(startedAt, style: .timer)
            .monospacedDigit()
            .font(.title2)
            .foregroundStyle(.orange)
    }
}
