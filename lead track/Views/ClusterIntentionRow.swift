import SwiftUI

/// One open intention inside its aspiration's Today cluster: a small dot in
/// the aspiration's color standing in for the mountain icon, the commitment,
/// and the same tick/progress anatomy and context menu as `IntentionRowView`
/// — re-skinned so the intention reads as a member of the cluster rather
/// than a separate section. Intentions never fold: stubs keep these rows.
struct ClusterIntentionRow: View {
    let intention: Intention

    var body: some View {
        HStack(spacing: 12) {
            dot
            Text(intention.title)
                .font(.subheadline)
                .foregroundStyle(Color.primary.opacity(0.85))
            Spacer()
            IntentionRowTrailing(intention: intention, accent: accent)
        }
        .padding(.vertical, 11)
        .contentShape(Rectangle())
        .intentionRowActions(intention)
    }

    private var accent: Color {
        MetricColor.color(named: intention.aspiration?.colorName)
    }

    /// Centered in the same 30 pt column as the metric icons above it.
    private var dot: some View {
        Circle()
            .fill(accent)
            .frame(width: 5, height: 5)
            .frame(width: 30)
    }
}
