import SwiftUI

/// A small pill linking back to an aspiration an item belongs to — shown on the
/// metric and project detail screens so the connection reads both ways.
struct AspirationChip: View {
    let aspiration: Aspiration

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: aspiration.displayIcon)
                .font(.caption2)
            Text(aspiration.title)
                .font(.caption)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .foregroundStyle(aspiration.displayColor)
        .background(aspiration.displayColor.opacity(0.14), in: Capsule())
    }
}

/// The horizontal row of back-link chips, one per aspiration. Renders nothing
/// when the item belongs to no aspirations, so existing detail screens are
/// untouched for items with none.
struct AspirationChipsRow: View {
    let aspirations: [Aspiration]

    var body: some View {
        if !aspirations.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(aspirations) { aspiration in
                        NavigationLink(value: aspiration) {
                            AspirationChip(aspiration: aspiration)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }
}
