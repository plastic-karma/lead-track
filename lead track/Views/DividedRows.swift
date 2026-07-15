import SwiftUI

/// The cluster cards' row-separator convention in one place: an inset
/// hairline between neighboring rows. The inset must visually clear the
/// rows' 30pt icon column plus its 12pt spacing.
enum ClusterRowStyle {
    static let dividerInset: CGFloat = 42
}

/// Rows with the shared inset hairline between neighbors — and, when
/// `dividerAfterLast`, after the final row too (the seam before a closing
/// insight line).
struct DividedRows<Item: Identifiable, Row: View>: View {
    let items: [Item]
    var dividerAfterLast = false
    @ViewBuilder let row: (Item) -> Row

    var body: some View {
        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
            row(item)
            if index < items.count - 1 || dividerAfterLast {
                Divider()
                    .padding(.leading, ClusterRowStyle.dividerInset)
            }
        }
    }
}
