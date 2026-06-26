import SwiftUI
import UIKit

extension Aspiration {
    /// The decoded cover photo, if one was set.
    var coverImage: Image? {
        guard let data = imageData, let uiImage = UIImage(data: data) else {
            return nil
        }
        return Image(uiImage: uiImage)
    }
}

/// The cover stand-in everywhere an aspiration is shown small: the photo cropped
/// to a rounded square, or the icon on a tint of the aspiration's color when
/// there's no photo.
struct AspirationThumbnail: View {
    let aspiration: Aspiration
    var size: CGFloat = 56

    var body: some View {
        Group {
            if let image = aspiration.coverImage {
                image.resizable().scaledToFill()
            } else {
                aspiration.displayColor.opacity(0.22)
                    .overlay {
                        Image(systemName: aspiration.displayIcon)
                            .font(.title3)
                            .foregroundStyle(aspiration.displayColor)
                    }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

/// One row of the Aspirations list: cover, title, and a one-line rollup summary.
struct AspirationCardView: View {
    let aspiration: Aspiration

    var body: some View {
        let rollup = AspirationRollup.compute(for: aspiration)
        HStack(spacing: 14) {
            AspirationThumbnail(aspiration: aspiration)
            VStack(alignment: .leading, spacing: 4) {
                Text(aspiration.title)
                    .font(.headline)
                    .lineLimit(1)
                Text(summary(rollup))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .cardSurface(alignment: .leading)
    }

    private func summary(_ rollup: AspirationRollup) -> String {
        if rollup.attachmentCount == 0 {
            return "Nothing attached yet"
        }
        if !rollup.hasData {
            return "Nothing logged yet"
        }
        return rollup.lifetimeSummary
    }
}
