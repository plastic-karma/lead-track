import SwiftUI

/// An adaptive grid of SF Symbol choices, the selected one highlighted. Shared
/// by the metric and aspiration forms so the picker stays identical across both.
struct IconGridPicker: View {
    let options: [String]
    @Binding var selection: String

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 44))],
            spacing: 12
        ) {
            ForEach(options, id: \.self) { option in
                button(option)
            }
        }
    }

    private func button(_ option: String) -> some View {
        Button {
            selection = option
        } label: {
            Image(systemName: option)
                .font(.title2)
                .frame(width: 44, height: 44)
                .background(
                    selection == option
                        ? Color.accentColor.opacity(0.2)
                        : Color.clear
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

/// An adaptive grid of the `MetricColor` palette, the selected swatch ringed.
/// Shared by the metric and aspiration forms.
struct ColorGridPicker: View {
    @Binding var selection: MetricColor

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 44))],
            spacing: 12
        ) {
            ForEach(MetricColor.allCases) { option in
                button(option)
            }
        }
    }

    private func button(_ option: MetricColor) -> some View {
        Button {
            selection = option
        } label: {
            Circle()
                .fill(option.color)
                .frame(width: 26, height: 26)
                .frame(width: 44, height: 44)
                .background(
                    selection == option
                        ? option.color.opacity(0.2)
                        : Color.clear
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option.label)
        .accessibilityAddTraits(selection == option ? .isSelected : [])
    }
}
