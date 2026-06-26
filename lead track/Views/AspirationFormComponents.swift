import SwiftUI

/// The small caps, tracked section label the aspiration form uses above every
/// block ("ASPIRATION", "WHY THIS MATTERS", "COLOR", "WHAT FEEDS THIS"), tinted
/// in the aspiration's identity color so the whole form shifts with the color row.
struct FormEyebrow: View {
    let text: String
    var tint: Color

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .tracking(0.8)
            .textCase(.uppercase)
            .foregroundStyle(tint)
    }
}

/// The round include/exclude control on every "what feeds this" row: a filled
/// tinted disc with a white check when selected, a hollow ring when not.
struct SelectionBadge: View {
    let isSelected: Bool
    var tint: Color
    var size: CGFloat = 26

    var body: some View {
        ZStack {
            if isSelected {
                Circle().fill(tint)
                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.5, weight: .bold))
                    .foregroundStyle(.white)
            } else {
                Circle().strokeBorder(Color.secondary.opacity(0.45), lineWidth: 1.5)
            }
        }
        .frame(width: size, height: size)
    }
}

/// The horizontal palette in the aspiration form: every `MetricColor` as a dot,
/// the selected one wearing a halo ring in its own color. Spacers justify the
/// dots edge to edge so the row fills the width like a swatch tray.
struct ColorSwatchRow: View {
    @Binding var selection: MetricColor

    var body: some View {
        HStack(spacing: 0) {
            ForEach(MetricColor.allCases) { option in
                swatch(option)
                if option != MetricColor.allCases.last {
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private func swatch(_ option: MetricColor) -> some View {
        Button {
            withAnimation(.snappy) { selection = option }
        } label: {
            ZStack {
                Circle()
                    .strokeBorder(option.color, lineWidth: 2)
                    .opacity(selection == option ? 1 : 0)
                Circle()
                    .fill(option.color)
                    .frame(width: 24, height: 24)
            }
            .frame(width: 34, height: 34)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option.label)
        .accessibilityAddTraits(selection == option ? .isSelected : [])
    }
}
