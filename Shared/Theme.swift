#if canImport(SwiftUI)
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Semantic chrome colors — the single source of truth for surfaces and
/// neutral fills, so a restyle is a one-file change shared by the app and
/// the widget extension. Metric identity colors live in `MetricColor`;
/// red is reserved for destructive actions and errors.
///
/// The neutrals are not pure gray: each carries a faint copper warmth so the
/// whole app reads as lit by the same light as the aspiration create sheet
/// rather than by a generic system gray. The warmth is resolved per
/// light/dark trait so surfaces stay legible in both.
enum Theme {
    #if os(iOS)
    /// Scrolling dashboard background behind the cards.
    static let screenBackground = warmNeutral(dark: 0.055, light: 0.96)

    /// Elevated card surface, a warm charcoal lifted off the background.
    static let cardBackground = warmNeutral(dark: 0.12, light: 0.995)

    /// Track behind progress rings and other inactive fills.
    static let inactive = warmNeutral(dark: 0.24, light: 0.87)

    /// Quiet warm chip behind card icons.
    static let chipFill = warmNeutral(dark: 0.16, light: 0.93)

    /// A soft copper atmosphere washing the top of a screen, echoing the
    /// aspiration create sheet. Fades to clear so cards sit on the base.
    static func wash(_ tint: Color) -> LinearGradient {
        LinearGradient(
            colors: [tint.opacity(0.16), .clear],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// The full screen fill: the warm base with the copper wash up top, bled
    /// under the safe area as one piece. Painted both behind the shell (so the
    /// color reaches past the status bar) and per screen (so it also covers the
    /// navigation stack's own opaque fill in the content area) — the page-style
    /// `TabView` insets each page below the status bar, so neither layer alone
    /// covers the whole screen, but together they read as one continuous fill.
    static var washedScreen: some View {
        screenBackground
            .overlay(alignment: .top) {
                wash(Color.accentColor)
                    .frame(height: 280)
            }
            .ignoresSafeArea()
    }

    /// A warm neutral built from a gray level plus a touch of red/green
    /// warmth, resolved per light/dark so surfaces stay legible in both.
    private static func warmNeutral(dark: Double, light: Double) -> Color {
        Color(uiColor: UIColor { traits in
            let base = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red: min(base + 0.018, 1),
                green: min(base + 0.008, 1),
                blue: base,
                alpha: 1
            )
        })
    }
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
