import SwiftUI

/// The capsule vocabulary of the weekly review's action rows: every "do
/// something" on an aspiration card lives in one calm line of these chips.
/// Three voices — a quiet neutral fill for narrative content and prompts, a
/// soft tinted fill for decisions offered on the card, and a hairline
/// outline for affordances that open or expand something.
struct ActionChip<Content: View>: View {
    enum Voice {
        /// Neutral fill — a kept moment, an unselected answer.
        case quiet
        /// Soft tinted fill, stretched to share its row equally — closure
        /// decisions and the selected answer.
        case decision(Color)
        /// Hairline tinted outline — set an intention, open the check-in.
        case opening(Color)
    }

    let voice: Voice
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(spacing: 6, content: content)
            .font(.caption.weight(weight))
            .foregroundStyle(foreground)
            .frame(maxWidth: stretched ? .infinity : nil)
            .padding(.vertical, 7)
            .padding(.horizontal, 12)
            .background(fill, in: Capsule())
            .overlay(border)
    }
}

// MARK: - Voice styling

extension ActionChip {
    private var stretched: Bool {
        if case .decision = voice { return true }
        return false
    }

    private var weight: Font.Weight {
        if case .quiet = voice { return .regular }
        return .medium
    }

    private var foreground: AnyShapeStyle {
        switch voice {
        case .quiet: AnyShapeStyle(.secondary)
        case let .decision(tint), let .opening(tint): AnyShapeStyle(tint)
        }
    }

    private var fill: Color {
        switch voice {
        case .quiet: Theme.chipFill
        case let .decision(tint): tint.opacity(0.12)
        case .opening: .clear
        }
    }

    @ViewBuilder
    private var border: some View {
        if case let .opening(tint) = voice {
            Capsule()
                .strokeBorder(tint.opacity(0.4), lineWidth: 1)
        }
    }
}

// MARK: - Flow

/// A leading-aligned wrap for the action row: chips flow left to right and
/// break onto new lines instead of squeezing, so a kept moment, the
/// intention affordance, and the check-in share one calm line — or two.
struct ChipFlow: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        arrange(in: proposal.width ?? .infinity, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal _: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
        let origins = arrange(in: bounds.width, subviews: subviews).origins
        for (subview, origin) in zip(subviews, origins) {
            subview.place(
                at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y),
                proposal: .unspecified
            )
        }
    }

    /// One pass over the chips at their ideal sizes: each gets an origin,
    /// wrapping whenever the next chip would overrun the width.
    private func arrange(in width: CGFloat, subviews: Subviews) -> (origins: [CGPoint], size: CGSize) {
        var origins: [CGPoint] = []
        var cursor = CGPoint.zero
        var lineHeight: CGFloat = 0
        var widest: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if cursor.x > 0, cursor.x + size.width > width {
                cursor = CGPoint(x: 0, y: cursor.y + lineHeight + spacing)
                lineHeight = 0
            }
            origins.append(cursor)
            cursor.x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
            widest = max(widest, cursor.x - spacing)
        }
        return (origins, CGSize(width: widest, height: cursor.y + lineHeight))
    }
}
