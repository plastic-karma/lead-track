import SwiftData
import SwiftUI

/// The Pulse of the aspiration detail — the app's only subjective series:
/// this week's alignment check-in, the honest twelve-week strip once enough
/// lifetime pulses exist, and (rarely) the divergence card, the Goodhart
/// alarm asking what changed. No streaks, no completion rate, no nagging:
/// absence is silence, never debt.
extension AspirationDetailView {
    var pulseSection: some View {
        Section("Pulse") {
            pulseComposerRow
            if aspiration.checkIns.count >= AspirationAlignment.minimumCheckIns {
                pulseHistoryRow
                divergenceRow
            } else {
                Text("Check in a few weeks running to see the shape.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            narrowingRow
        }
        .onAppear { pulseNoteDraft = currentCheckIn?.note ?? "" }
    }
}

// MARK: - Composer

extension AspirationDetailView {
    private var currentCheckIn: AspirationCheckIn? {
        AspirationAlignment.currentWeekCheckIn(of: aspiration)
    }

    private var pulseComposerRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Is this effort still serving the why?")
                .font(.subheadline)
            HStack(spacing: 8) {
                ForEach(AlignmentRating.allCases, id: \.rawValue) { rating in
                    pulseRatingButton(rating)
                }
            }
            TextField("Add a note (optional)", text: $pulseNoteDraft)
                .font(.callout)
                .focused($pulseNoteFocused)
                .onSubmit(commitPulseNote)
        }
        .padding(.vertical, 4)
    }

    private func pulseRatingButton(_ rating: AlignmentRating) -> some View {
        Button {
            recordPulse(rating)
        } label: {
            Text(rating.shortLabel)
                .font(.caption.weight(.medium))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .tint(currentCheckIn?.rating == rating ? aspiration.displayColor : nil)
    }

    /// Upserts this calendar week's row — at most one, the latest edit wins.
    /// A note typed before any rating rides along when the rating lands.
    private func recordPulse(_ rating: AlignmentRating) {
        let note = pulseNoteDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        withAnimation {
            if let existing = currentCheckIn {
                existing.ratingRaw = rating.rawValue
            } else {
                modelContext.insert(AspirationCheckIn(
                    aspiration: aspiration,
                    rating: rating,
                    weekStart: Intention.weekStart(containing: .now),
                    note: note
                ))
            }
        }
    }

    /// Notes attach to a check-in, never stand alone — a note without a
    /// rating isn't a pulse, so submitting without one keeps the draft.
    private func commitPulseNote() {
        currentCheckIn?.note = pulseNoteDraft.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - History strip

extension AspirationDetailView {
    /// One dot per trailing week, three fill levels, hollow when skipped —
    /// no axis, no numbers, no percentage: the honest shape and nothing more.
    private var pulseHistoryRow: some View {
        let weeks = AspirationAlignment.trailingWeekStarts(
            weeks: AspirationAlignment.historyWeeks, now: .now, calendar: .current
        )
        let ratings = Dictionary(
            AspirationAlignment.series(from: aspiration.checkIns)
                .map { ($0.weekStart, $0.rating) },
            uniquingKeysWith: { _, latest in latest }
        )
        return HStack(spacing: 6) {
            ForEach(weeks, id: \.self) { week in
                pulseDot(rating: ratings[week])
            }
        }
        .padding(.vertical, 2)
        .accessibilityLabel("Last twelve weeks of check-ins")
    }

    @ViewBuilder
    private func pulseDot(rating: Int?) -> some View {
        if let rating {
            Circle()
                .fill(aspiration.displayColor.opacity(dotOpacity(rating)))
                .frame(width: 10, height: 10)
        } else {
            Circle()
                .strokeBorder(Theme.inactive, lineWidth: 1.5)
                .frame(width: 10, height: 10)
        }
    }

    private func dotOpacity(_ rating: Int) -> Double {
        switch AlignmentRating(rawValue: rating) {
        case .serving: 1
        case .unsure: 0.55
        default: 0.25
        }
    }
}

// MARK: - Divergence & narrowing

extension AspirationDetailView {
    /// The Goodhart alarm, one quiet card: it earns its place only when
    /// ratings fell while effort rose in the same window (see
    /// `AspirationAlignment.divergence`).
    @ViewBuilder
    private var divergenceRow: some View {
        if divergence != nil {
            VStack(alignment: .leading, spacing: 8) {
                Text(
                    "Effort here is up over the last six weeks, but your "
                        + "check-ins say it's serving the why less. Worth "
                        + "asking what changed?"
                )
                .font(.callout)
                Button("Reflect") { pulseNoteFocused = true }
                    .font(.caption.weight(.medium))
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
            }
            .padding(.vertical, 4)
        }
    }

    private var divergence: AspirationAlignment.Divergence? {
        AspirationAlignment.divergence(
            alignment: AspirationAlignment.series(from: aspiration.checkIns),
            effort: AspirationAlignment.effortSeries(
                for: aspiration, weeks: AspirationAlignment.divergenceWindowWeeks
            )
        )
    }

    /// The narrowing observation (see `MeasureHealth`) — its remedy is a
    /// subjective pulse, not a settings screen, so the action is checking in.
    @ViewBuilder
    private var narrowingRow: some View {
        if let narrowing = MeasureHealth.detectNarrowing(for: aspiration) {
            VStack(alignment: .leading, spacing: 8) {
                Text(narrowing.line)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Check in") { pulseNoteFocused = true }
                    .font(.caption.weight(.medium))
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
            }
            .padding(.vertical, 4)
        }
    }
}
