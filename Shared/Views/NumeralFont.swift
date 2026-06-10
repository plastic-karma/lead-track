#if canImport(SwiftUI)
import SwiftUI

extension View {
    /// Rounded design plus monospaced digits — the treatment every data
    /// numeral gets on the watch, in widgets, and in the Live Activity
    /// (the iOS app's standalone numerals use `numeralStyle` instead),
    /// so live values don't jitter as they count.
    func roundedDigits(
        _ textStyle: Font.TextStyle,
        weight: Font.Weight? = nil
    ) -> some View {
        let base = Font.system(textStyle, design: .rounded)
        return font(weight.map { base.weight($0) } ?? base)
            .monospacedDigit()
    }
}
#endif
