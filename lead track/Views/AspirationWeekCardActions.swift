import SwiftUI

/// The action row of an aspiration's review card — one calm line of chips
/// where every "do something" lives: the week's kept moments (content before
/// prompts), the affordance to keep one when none exist yet, the intention
/// chip, and the check-in, which expands its composer right below the row.
/// No dismiss button anywhere — scrolling past *is* the dismissal, and a
/// skipped week leaves no trace.
extension AspirationWeekCard {
    /// Whether the check-in belongs on the row: offered and still open, or
    /// answered this visit (the composer stays on stage for its note).
    var checkInAvailable: Bool {
        onCheckIn != nil && (week.offersCheckIn || pulseRating != nil)
    }

    private var actionRowVisible: Bool {
        !week.moments.isEmpty || onKeepMoment != nil
            || onSetIntention != nil || checkInAvailable
    }

    @ViewBuilder
    var actionBlock: some View {
        if actionRowVisible {
            Divider()
            actionRow
            pulseComposer
        }
    }

    private var actionRow: some View {
        ChipFlow {
            ForEach(week.moments) { line in
                momentChip(line)
            }
            keepMomentChip
            intentionChip
            checkInChip
        }
    }

    /// Chip glyphs sit a step below the label size, drawn a touch heavier so
    /// they read at eleven points.
    private func chipGlyph(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.caption2.weight(.semibold))
    }
}

// MARK: - Chips

extension AspirationWeekCard {
    /// A kept moment: the weekday it happened and its testimony, truncated —
    /// the full story lives behind the card's tap, like the day-by-day.
    private func momentChip(_ line: WeeklyReview.MomentLine) -> some View {
        ActionChip(voice: .quiet) {
            Text(line.occurredAt.formatted(.dateTime.weekday(.abbreviated)))
                .foregroundStyle(.tertiary)
            Text(line.text)
                .lineLimit(1)
                .frame(maxWidth: 150, alignment: .leading)
        }
    }

    /// The prompt to keep one, only while the week has none — content
    /// replaces its own affordance.
    @ViewBuilder
    private var keepMomentChip: some View {
        if week.moments.isEmpty, let onKeepMoment {
            Button(action: onKeepMoment) {
                ActionChip(voice: .quiet) {
                    chipGlyph("plus")
                    Text("Keep a moment")
                }
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var intentionChip: some View {
        if let onSetIntention {
            Button(action: onSetIntention) {
                ActionChip(voice: .opening(.accentColor)) {
                    chipGlyph("plus")
                    Text("Intention")
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Set an intention")
        }
    }

    /// Opens (and closes) the composer below the row; wears the aspiration's
    /// color, filled while the composer is on stage.
    @ViewBuilder
    private var checkInChip: some View {
        if checkInAvailable {
            Button {
                withAnimation(.snappy) {
                    pulseExpanded.toggle()
                }
            } label: {
                ActionChip(voice: pulseExpanded ? .decision(tint) : .opening(tint)) {
                    chipGlyph("record.circle")
                    Text("Check in")
                }
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Pulse composer

extension AspirationWeekCard {
    /// The weekly alignment pulse, expanded in place from its chip: the one
    /// question, three answers sitting visually equal, and — once one is
    /// chosen — room for a note.
    @ViewBuilder
    private var pulseComposer: some View {
        if pulseExpanded, checkInAvailable {
            Text("Is this effort still serving the why?")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                ForEach(AlignmentRating.allCases, id: \.rawValue) { rating in
                    ratingChip(rating)
                }
            }
            noteField
        }
    }

    private func ratingChip(_ rating: AlignmentRating) -> some View {
        Button {
            pulseRating = rating
            onCheckIn?(rating, nil)
        } label: {
            ActionChip(voice: pulseRating == rating ? .decision(tint) : .quiet) {
                Text(rating.shortLabel)
                    .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var noteField: some View {
        if pulseRating != nil {
            TextField("Add a note (optional)", text: $pulseNote)
                .font(.caption)
                .textFieldStyle(.roundedBorder)
                .onSubmit(submitPulseNote)
        }
    }

    private func submitPulseNote() {
        guard let rating = pulseRating else { return }
        let trimmed = pulseNote.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        onCheckIn?(rating, trimmed)
    }
}
