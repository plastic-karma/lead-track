import SwiftUI

/// The shared hour/minute duration input — two steppers and their seconds
/// conversion — used by the manual log sheet and the countdown starter so
/// the input style, its bounds, and the math can only change in one place.
struct HourMinuteDurationPicker: View {
    @Binding var hours: Int
    @Binding var minutes: Int

    var body: some View {
        Stepper("\(hours) h", value: $hours, in: 0 ... 23)
        Stepper("\(minutes) min", value: $minutes, in: 0 ... 59)
    }

    static func duration(hours: Int, minutes: Int) -> TimeInterval {
        TimeInterval(hours * 3600 + minutes * 60)
    }
}
