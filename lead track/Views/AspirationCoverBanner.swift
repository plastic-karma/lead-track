import SwiftUI

/// The full-bleed cover of the aspiration detail screen: the photo (or a band
/// in the aspiration's color when there's none) under a two-part scrim — the
/// top edge darkened so the floating nav glass stays legible, the bottom so
/// the heading does — with the "since" eyebrow and the title resting on the
/// bottom edge, album-style.
struct AspirationCoverBanner: View {
    let aspiration: Aspiration

    var body: some View {
        AspirationBannerHeading(
            icon: aspiration.displayIcon, title: aspiration.title, createdAt: aspiration.createdAt
        )
        .padding(.top, 120)
        .frame(maxWidth: .infinity, minHeight: 344, alignment: .bottomLeading)
        .background {
            AspirationBannerBackground(aspiration: aspiration)
                .overlay { scrim }
        }
        .clipped()
    }

    private var scrim: some View {
        LinearGradient(
            stops: [
                .init(color: .black.opacity(0.28), location: 0),
                .init(color: .clear, location: 0.26),
                .init(color: .clear, location: 0.4),
                .init(color: .black.opacity(0.64), location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

private struct AspirationBannerHeading: View {
    let icon: String
    let title: String
    let createdAt: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.caption)
                Text("Since \(createdAt.formatted(.dateTime.month(.wide).year()))")
                    .font(.caption2.weight(.semibold))
                    .textCase(.uppercase)
                    .kerning(1.4)
            }
            .foregroundStyle(.white.opacity(0.88))
            Text(title)
                .font(.largeTitle.bold())
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.25), radius: 6, y: 1)
        }
        .frame(maxWidth: 680, alignment: .leading)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }
}

/// The story card's closing ledger: the lifetime figure on the numeral scale,
/// the trailing-30-day momentum line beneath it.
struct AspirationRollupHeader: View {
    let lifetimeSummary: String
    let recentParts: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(lifetimeSummary)
                .numeralStyle(.value)
                .monospacedDigit()
                .fixedSize(horizontal: false, vertical: true)
            if !recentParts.isEmpty {
                Label(
                    "\(recentParts.joined(separator: " · ")) in the last 30 days",
                    systemImage: "arrow.up.right"
                )
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct AspirationBannerBackground: View {
    let aspiration: Aspiration

    var body: some View {
        Group {
            if let image = aspiration.coverImage {
                image.resizable().scaledToFill()
            } else {
                LinearGradient(
                    colors: [aspiration.displayColor, aspiration.displayColor.opacity(0.55)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
    }
}
