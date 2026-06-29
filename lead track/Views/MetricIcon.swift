import SwiftUI

/// A metric's glyph on a rounded tile tinted with its identity color: a soft
/// fill of the color behind the symbol drawn in the full color. Shared by the
/// dashboard cards and the weekly-review cards so a metric reads the same
/// everywhere, and so the Today list gains rhythm instead of a row of
/// identical gray chips.
struct MetricIcon: View {
    let systemName: String
    var tint: Color = .accentColor
    var size: CGFloat = 36

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(
                RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                    .fill(tint.opacity(0.18))
            )
    }
}
