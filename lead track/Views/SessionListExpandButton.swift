import SwiftUI

/// A list row that toggles a session list between showing a capped preview
/// and showing every entry. Renders nothing when the list fits within the
/// preview limit.
struct SessionListExpandButton: View {
    let totalCount: Int
    @Binding var isExpanded: Bool

    var body: some View {
        if totalCount > SessionStatistics.sessionListPreviewLimit {
            Button {
                withAnimation {
                    isExpanded.toggle()
                }
            } label: {
                Label(label, systemImage: icon)
                    .font(.subheadline)
            }
        }
    }

    private var label: String {
        isExpanded ? "Show Less" : "Show All (\(totalCount))"
    }

    private var icon: String {
        isExpanded ? "chevron.up" : "chevron.down"
    }
}
