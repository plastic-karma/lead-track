import SwiftUI

/// One open intention inside its aspiration's Today cluster: a small kind
/// glyph in the aspiration's color standing in for the mountain icon, the
/// commitment in the serif vow register (`IntentionVoice`) with the
/// principle it serves threaded beneath, and the same tick/progress anatomy
/// and context menu as `IntentionRowView` — re-skinned so the intention
/// reads as a member of the cluster rather than a separate section.
/// Reflective rows, which carry no control by doctrine, close with a quiet
/// "held through Sunday" instead — identity, never progress. Intentions
/// never fold: stubs keep these rows.
struct ClusterIntentionRow: View {
    let intention: Intention

    var body: some View {
        HStack(spacing: 12) {
            glyph
            titleBlock
            Spacer()
            trailing
        }
        .padding(.vertical, 11)
        .contentShape(Rectangle())
        .intentionRowActions(intention)
    }

    private var accent: Color {
        MetricColor.color(named: intention.aspiration?.colorName)
    }
}

// MARK: - Leading glyph

extension ClusterIntentionRow {
    /// Centered in the same 30 pt column as the metric icons above it; one
    /// quiet symbol per kind — held in the head, ticked by hand, or flowing
    /// from a metric.
    private var glyph: some View {
        Image(systemName: glyphName)
            .font(.caption)
            .foregroundStyle(accent)
            .frame(width: 30)
    }

    private var glyphName: String {
        switch intention.kind {
        case .reflective: "moon"
        case .counted: "hand.tap"
        case .derived: "link"
        }
    }
}

// MARK: - Title

extension ClusterIntentionRow {
    @ViewBuilder
    private var titleBlock: some View {
        if let serves = intention.principle?.text, !serves.isEmpty {
            VStack(alignment: .leading, spacing: 3) {
                title
                IntentionServesLine(text: serves, accent: accent)
            }
        } else {
            title
        }
    }

    private var title: some View {
        Text(intention.title)
            .font(IntentionVoice.title)
    }
}

// MARK: - Trailing

extension ClusterIntentionRow {
    /// Counted and derived rows keep the shared tick/progress anatomy;
    /// reflective rows — whose trailing side is empty by doctrine — say what
    /// they are instead: held all week, closing at the review. A state,
    /// never a score.
    @ViewBuilder
    private var trailing: some View {
        if intention.kind == .reflective {
            Text("held through \(closeDayName)")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            IntentionRowTrailing(intention: intention, accent: accent)
        }
    }

    private var closeDayName: String {
        intention.weekLastDay().formatted(.dateTime.weekday(.wide))
    }
}
