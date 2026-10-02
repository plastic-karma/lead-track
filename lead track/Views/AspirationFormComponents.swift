import SwiftUI

/// The tracked section label keeps readable text neutral and uses a small dot
/// to carry the aspiration's color without relying on it for contrast.
struct FormEyebrow: View {
    let text: String
    var tint: Color

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(tint)
                .frame(width: 6, height: 6)
                .accessibilityHidden(true)
            Text(text)
                .font(.caption.weight(.semibold))
                .tracking(0.8)
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
        }
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

/// The aspiration palette wraps rather than compressing its touch targets on
/// smaller screens. Each swatch has a 44-point target and a selection ring.
struct ColorSwatchRow: View {
    @Binding var selection: MetricColor

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: 8)], spacing: 8) {
            ForEach(MetricColor.allCases) { option in
                swatch(option)
            }
        }
    }

    private func swatch(_ option: MetricColor) -> some View {
        Button {
            selection = option
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
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option.label)
        .accessibilityAddTraits(selection == option ? .isSelected : [])
    }
}

extension Set {
    /// A key-path projection for selection controls backed by membership.
    subscript(selected element: Element) -> Bool {
        get { contains(element) }
        set {
            if newValue { insert(element) } else { remove(element) }
        }
    }
}
