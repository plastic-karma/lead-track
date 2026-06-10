import SwiftUI

extension View {
    /// The app's haptic vocabulary for recording state: an impact when a
    /// timer starts, success when it stops.
    func recordingFeedback(isActive: Bool) -> some View {
        sensoryFeedback(trigger: isActive) { wasActive, isActive in
            if !wasActive, isActive {
                .impact(weight: .medium)
            } else if wasActive, !isActive {
                .success
            } else {
                nil
            }
        }
    }
}
