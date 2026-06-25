#if canImport(SwiftUI)
import SwiftUI

extension Text {
    /// A self-updating live timer for a running session. When `countdown` is
    /// set it counts down across that range, resting at 0:00 once reached;
    /// otherwise it counts up from `origin`. Returning `Text` keeps every call
    /// site free to apply its own numeral styling, the same as before.
    init(liveTimer countdown: ClosedRange<Date>?, countingUpFrom origin: Date) {
        if let countdown {
            self.init(timerInterval: countdown, countsDown: true)
        } else {
            self.init(origin, style: .timer)
        }
    }
}
#endif
