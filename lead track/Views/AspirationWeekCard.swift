import SwiftUI

/// One aspiration's card at the heart of the weekly review: what landed in
/// the reviewed seven days (lifetime totals live on the aspiration's own
/// screen, never here), then the week's intentions — last week's awaiting
/// their decision, the open ones' factual accumulation, and the affordance to
/// set another. The day-by-day rhythm lives behind a tap on the week detail
/// screen, so the card itself stays calm.
struct AspirationWeekCard: View {
    let week: WeeklyReview.AspirationWeek
    /// Last week's unclosed intentions, decided right on the card.
    var closures: [WeeklyReview.IntentionClosure] = []
    /// Opens the intention form; nil (earlier weeks) hides the affordance.
    var onSetIntention: (() -> Void)?
    /// Receives a closure row's decision, keyed by the intention's ID.
    var onClosureAction: ((IntentionClosureAction, String) -> Void)?
    /// Records this week's alignment pulse (rating, then optionally a note);
    /// nil (earlier weeks, unmapped aspirations) hides the composer.
    var onCheckIn: ((AlignmentRating, String?) -> Void)?
    /// The rating tapped this visit, keeping the note field on stage after
    /// the write flips `week.offersCheckIn` off.
    @State private var pulseRating: AlignmentRating?
    @State private var pulseNote = ""

    private var tint: Color {
        MetricColor.color(named: week.colorName)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            weekLine
            footer
            intentionsBlock
            pulseBlock
        }
        .cardSurface()
    }
}

// MARK: - Effort pieces

extension AspirationWeekCard {
    private var header: some View {
        HStack(spacing: 12) {
            MetricIcon(systemName: week.icon, tint: tint)
            Text(week.title)
                .font(.headline)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    /// The reviewed week's effort is the card's one figure — the aspiration's
    /// lifetime totals live on its own screen, never in the review.
    @ViewBuilder
    private var weekLine: some View {
        if week.totals.isEmpty {
            Text("Quiet this week")
                .font(.title3)
                .foregroundStyle(.secondary)
        } else {
            Text(week.totals.map(\.text).joined(separator: " · "))
                .numeralStyle(.value)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
    }

    @ViewBuilder
    private var footer: some View {
        if week.sessionCount > 0 {
            Text("\(ValueFormatter.sessions(week.sessionCount)) · \(week.activeDays) days active")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Intentions

extension AspirationWeekCard {
    /// The week's commitments, folded into the card so the aspiration is the
    /// one place its week lives. Absent entirely on earlier weeks, where no
    /// intention machinery applies.
    @ViewBuilder
    private var intentionsBlock: some View {
        if !closures.isEmpty || !week.intentions.isEmpty || onSetIntention != nil {
            Divider()
            closuresBlock
            ForEach(week.intentions) { line in
                intentionRow(line)
            }
            setIntentionButton
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

    private func intentionRow(_ line: WeeklyReview.IntentionLine) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(tint)
                .frame(width: 6, height: 6)
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
    }

    @ViewBuilder
    private var setIntentionButton: some View {
        if let onSetIntention {
            Button(action: onSetIntention) {
                Label("Set an intention", systemImage: "plus.circle")
                    .font(.subheadline)
            }
            .buttonStyle(.borderless)
        }
    }
}

// MARK: - Pulse

extension AspirationWeekCard {
    /// The weekly alignment pulse and, rarely, the narrowing line. No dismiss
    /// button anywhere — scrolling past *is* the dismissal, and a skipped
    /// week leaves no trace.
    @ViewBuilder
    private var pulseBlock: some View {
        if week.narrowing != nil || composerVisible {
            Divider()
            narrowingLine
            pulseComposer
        }
    }

    private var composerVisible: Bool {
        onCheckIn != nil && (week.offersCheckIn || pulseRating != nil)
    }

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

    @ViewBuilder
    private var pulseComposer: some View {
        if composerVisible {
            Text("Is this effort still serving the why?")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                ForEach(AlignmentRating.allCases, id: \.rawValue) { rating in
                    pulseButton(rating)
                }
            }
            if pulseRating != nil {
                TextField("Add a note (optional)", text: $pulseNote)
                    .font(.caption)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(submitPulseNote)
            }
        }
    }

    private func pulseButton(_ rating: AlignmentRating) -> some View {
        Button {
            pulseRating = rating
            onCheckIn?(rating, nil)
        } label: {
            Text(rating.shortLabel)
                .font(.caption.weight(.medium))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .tint(pulseRating == rating ? tint : nil)
    }

    private func submitPulseNote() {
        guard let rating = pulseRating else { return }
        let trimmed = pulseNote.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        onCheckIn?(rating, trimmed)
    }
}
