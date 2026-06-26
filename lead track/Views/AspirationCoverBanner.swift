import SwiftUI

/// The full-bleed header of the aspiration detail screen: the cover photo (or a
/// band in the aspiration's color when there's none) with the icon and title
/// overlaid, kept legible by a bottom gradient scrim.
struct AspirationCoverBanner: View {
    let aspiration: Aspiration

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            background
            scrim
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: aspiration.displayIcon)
                    .font(.title2)
                Text(aspiration.title)
                    .font(.largeTitle.bold())
                    .lineLimit(2)
            }
            .foregroundStyle(.white)
            .padding(20)
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
        .clipped()
    }

    @ViewBuilder
    private var background: some View {
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

    private var scrim: some View {
        LinearGradient(
            colors: [.clear, .black.opacity(0.45)],
            startPoint: .center,
            endPoint: .bottom
        )
    }
}

/// The rollup headline: the lifetime breakdown on top, the trailing-30-day
/// momentum line below it.
struct AspirationRollupHeader: View {
    let rollup: AspirationRollup

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(rollup.lifetimeSummary)
                .font(.title3.weight(.semibold))
            if !rollup.recentParts.isEmpty {
                Label(
                    "\(rollup.recentParts.joined(separator: " · ")) in the last 30 days",
                    systemImage: "arrow.up.right"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
