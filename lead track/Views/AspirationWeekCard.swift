import SwiftUI

/// One aspiration's card at the heart of the weekly review: what landed in
/// the reviewed seven days (lifetime totals live on the aspiration's own
/// screen, never here), then the week's intentions — last week's awaiting
/// their decision, the open ones' factual accumulation on a thin track —
/// and one calm action row where every "do something" lives as a chip:
/// the kept moments, the intention affordance, and the check-in, which
/// expands its composer in place (see `AspirationWeekCardActions`). The
/// day-by-day rhythm waits behind a tap on the week detail screen, so the
/// card itself stays calm under its soft wash of the aspiration's color.
/// The header folds the card to one summary line and back — its body keeps
/// the drill-in tap, the way a Today stub's header folds its cluster.
struct AspirationWeekCard: View {
    let week: WeeklyReview.AspirationWeek
    /// Last week's unclosed intentions, decided right on the card.
    var closures: [WeeklyReview.IntentionClosure] = []
    /// Opens the intention form; nil (earlier weeks) hides the chip.
    var onSetIntention: (() -> Void)?
    /// Receives a closure row's decision, keyed by the intention's ID.
    var onClosureAction: ((IntentionClosureAction, String) -> Void)?
    /// Records this week's alignment pulse (rating, then optionally a note);
    /// nil (earlier weeks, unmapped aspirations) hides the check-in chip.
    var onCheckIn: ((AlignmentRating, String?) -> Void)?
    /// Opens the moment composer pre-bound to this aspiration; nil (earlier
    /// weeks, unmapped aspirations) hides the chip. Moment *chips* still
    /// render without it — they are narrative, shown on browsed weeks too.
    var onKeepMoment: (() -> Void)?
    /// Whether the card is folded to its header line. The review screen owns
    /// the flag — per-card, transient, never persisted — so sibling cards
    /// fold independently, like the Today tab's stubs.
    @Binding var isCollapsed: Bool
    /// Whether the check-in chip has opened its composer. Internal (not
    /// private) so the action row in its own file can drive it.
    @State var pulseExpanded = false
    /// The rating tapped this visit, keeping the composer on stage after
    /// the write flips `week.offersCheckIn` off. Internal, like above.
    @State var pulseRating: AlignmentRating?
    @State var pulseNote = ""

    /// The aspiration's identity color. Internal so the action row in its
    /// own file wears the same tint.
    var tint: Color {
        MetricColor.color(named: week.colorName)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            if !isCollapsed {
                weekLine
                commitmentsBlock
                actionBlock
            }
        }
        .cardSurface(washTint: tint)
    }
}

// MARK: - Effort pieces

extension AspirationWeekCard {
    /// The card's fold handle: tapping the header folds the card to this one
    /// line and back (the rotating chevron says so), leaving the body below
    /// as the card's drill-in surface.
    private var header: some View {
        Button {
            withAnimation(.snappy) { isCollapsed.toggle() }
        } label: {
            headerLabel
        }
        .buttonStyle(.plain)
        .accessibilityHint(isCollapsed ? "Expand" : "Collapse")
    }

    private var headerLabel: some View {
        HStack(spacing: 12) {
            MetricIcon(systemName: week.icon, tint: tint)
            VStack(alignment: .leading, spacing: 1) {
                Text(week.title)
                    .font(.headline)
                headerCaption
            }
            Spacer()
            Image(systemName: "chevron.down")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
                .rotationEffect(.degrees(isCollapsed ? 0 : 180))
        }
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var headerCaption: some View {
        if let line = captionLine {
            Text(line)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    /// Folded, the caption carries the week's one figure so the line still
    /// reviews; expanded, the figure sits on `weekLine` and the caption
    /// counts the engagement.
    private var captionLine: String? {
        if isCollapsed { return totalsText ?? "Quiet this week" }
        guard week.sessionCount > 0 else { return nil }
        return "\(ValueFormatter.sessions(week.sessionCount)) · \(week.activeDays) days active"
    }

    /// The week's totals joined into one line, nil when nothing landed.
    private var totalsText: String? {
        week.totals.isEmpty ? nil : week.totals.map(\.text).joined(separator: " · ")
    }

    /// The reviewed week's effort is the card's one figure — the aspiration's
    /// lifetime totals live on its own screen, never in the review.
    @ViewBuilder
    private var weekLine: some View {
        if let totalsText {
            Text(totalsText)
                .numeralStyle(.value)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        } else {
            Text("Quiet this week")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Commitments

extension AspirationWeekCard {
    /// The week's commitments, folded into the card so the aspiration is the
    /// one place its week lives. Absent entirely on earlier weeks, where no
    /// intention machinery applies.
    @ViewBuilder
    private var commitmentsBlock: some View {
        if !closures.isEmpty || !week.intentions.isEmpty || week.narrowing != nil {
            Divider()
            closuresBlock
            ForEach(week.intentions) { line in
                intentionRow(line)
            }
            narrowingLine
        }
    }

    @ViewBuilder
    private var closuresBlock: some View {
        if !closures.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("From last week")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                ForEach(closures) { closure in
                    IntentionClosureRow(closure: closure) { action in
                        onClosureAction?(action, closure.id)
                    }
                }
            }
        }
    }

    /// The commitment and its factual accumulation: the reading at the
    /// trailing edge, the same share on a thin track in the aspiration's
    /// color. Reflective intentions carry the title alone.
    private func intentionRow(_ line: WeeklyReview.IntentionLine) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 10) {
                Text(line.title)
                    .font(.subheadline)
                Spacer()
                if let progress = line.progressText {
                    Text(progress)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            if let fraction = line.progressFraction {
                ProgressTrack(fraction: fraction, tint: tint)
                    .frame(height: 3)
            }
        }
    }

    /// The narrowing observation (see `MeasureHealth`) — rare, and quiet
    /// among the commitments it speaks about.
    @ViewBuilder
    private var narrowingLine: some View {
        if let narrowing = week.narrowing {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "arrow.triangle.merge")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 24)
                Text(narrowing.line)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
