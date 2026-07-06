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

    /// A soft atmosphere washing down from the top of a surface, echoing the
    /// aspiration create sheet. Fades to clear so content sits on the base;
    /// `peak` sets how strongly it opens — 0.16 for a whole screen, quieter
    /// for a card.
    static func wash(_ tint: Color, peak: Double = 0.16) -> LinearGradient {
        LinearGradient(
            colors: [tint.opacity(peak), .clear],
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
extension Theme {
    /// The card's rounded surface, optionally opening with a soft wash of an
    /// identity color across its top — how an aspiration card wears its
    /// color without inking the content.
    static func cardShape(washTint: Color? = nil) -> some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(cardBackground)
            .overlay(alignment: .top) {
                if let washTint {
                    wash(washTint, peak: 0.1)
                        .frame(height: 68)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: cardShadow, radius: 10, y: 2)
    }
}

extension View {
    /// The standard elevated card: 16pt padded content on the rounded
    /// surface with the soft shadow, full width unless constrained. A
    /// `washTint` opens the card with a soft wash of that color.
    func cardSurface(alignment: Alignment = .topLeading, washTint: Color? = nil) -> some View {
        padding(16)
            .frame(maxWidth: .infinity, alignment: alignment)
            .background(Theme.cardShape(washTint: washTint))
    }
}
#endif
#endif
