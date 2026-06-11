#if canImport(SwiftUI)
import SwiftUI

/// Semantic chrome colors — the single source of truth for surfaces and
/// neutral fills, so a restyle is a one-file change shared by the app and
/// the widget extension. Metric identity colors live in `MetricColor`;
/// red is reserved for destructive actions and errors.
enum Theme {
    #if os(iOS)
    /// Scrolling dashboard background behind the cards.
    static let screenBackground = Color(.systemGroupedBackground)

    /// Elevated card surface.
    static let cardBackground = Color(.secondarySystemGroupedBackground)

    /// Track behind progress rings and other inactive fills.
    static let inactive = Color(.systemGray5)

    /// Quiet monochrome chip behind card icons.
    static let chipFill = Color(.systemGray6)
    #endif

    /// Soft elevation under cards, replacing hairline borders.
    static let cardShadow = Color.black.opacity(0.05)
}

#if os(iOS)
extension View {
    /// The standard elevated card: 16pt padded content on the rounded
    /// surface with the soft shadow, full width unless constrained.
    func cardSurface(alignment: Alignment = .topLeading) -> some View {
        padding(16)
            .frame(maxWidth: .infinity, alignment: alignment)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Theme.cardBackground)
                    .shadow(color: Theme.cardShadow, radius: 10, y: 2)
            )
    }
}
#endif
#endif
