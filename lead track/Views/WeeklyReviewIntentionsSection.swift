import SwiftData
import SwiftUI

/// A closure decision made on one review row.
enum IntentionClosureAction {
    case outcome(IntentionOutcome)
    case setAgain
    case acceptPromotion(IntentionPromotion)
    case declinePromotion
}

// MARK: - Sections

/// The intention layer of the Week tab: closure decisions for last week's
/// open intentions and the weekly alignment pulse per active aspiration.
/// Restored after the aspiration-card retirement (PR #72) left the whole
/// lifecycle unreachable — without these, open intentions froze unclosed
/// forever and the "story so far" starved. Both sections render nothing
/// while the features are unused — additive, never a fork.
extension WeeklyReviewView {
    @ViewBuilder
    func intentionsSection(_ review: WeeklyReview) -> some View {
        if !review.intentionClosures.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                sectionBreak("Intentions to close")
                ForEach(review.intentionClosures) { closure in
                    IntentionClosureRow(closure: closure) { action in
                        handle(action, closureID: closure.id)
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    /// The weekly alignment pulse, one row per aspiration still open for it.
    /// An answered aspiration stays on stage for the rest of the visit so
    /// its note field doesn't vanish mid-typing; skipping remains
    /// structurally invisible — scrolling past is the dismissal.
    ///
    /// The header's close button — or a sideways swipe — sends the whole
    /// section away until next week; `WeeklyCheckInDismissal` remembers the
    /// week, so it returns on its own once the week rolls over.
    @ViewBuilder
    func checkInSection(_ review: WeeklyReview) -> some View {
        let open = review.aspirationWeeks.filter {
            $0.offersCheckIn || pulsedAspirations.contains($0.id)
        }
        if review.weeksBack == 0, !open.isEmpty,
           !WeeklyCheckInDismissal.isDismissed(storedWeekStart: dismissedCheckInWeek)
        {
            SwipeToDismiss(onDismiss: dismissCheckIn) {
                checkInBody(open)
            }
        }
    }

    /// The check-in section's content, split out so `SwipeToDismiss` can carry
    /// it: a header that closes the section, the prompt, then one
    /// alignment-pulse row per still-open aspiration.
    private func checkInBody(_ open: [WeeklyReview.AspirationWeek]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            checkInHeader
            Text("Is this effort still serving the why?")
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(open) { week in
                pulseRow(for: week)
            }
        }
        .padding(.horizontal)
    }

    /// The section seam with a quiet close button on the title row, so the
    /// check-in can be sent away for the week by an obvious tap — not only the
    /// swipe, which is easy to miss on a scrolling screen.
    private var checkInHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
            HStack {
                Text("Check-in")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button(action: dismissCheckIn) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss until next week")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Hides the check-in for the rest of the current calendar week; it comes
    /// back on its own once the week rolls over (see `WeeklyCheckInDismissal`).
    /// Animated so the section slides away and the rows below close the gap.
    private func dismissCheckIn() {
        withAnimation(.easeOut(duration: 0.2)) {
            dismissedCheckInWeek = WeeklyCheckInDismissal.marker(for: .now)
        }
    }

    @ViewBuilder
    private func pulseRow(for week: WeeklyReview.AspirationWeek) -> some View {
        if let aspiration = aspiration(for: week.id) {
            AspirationPulseRow(title: week.title) { rating, note in
                recordCheckIn(rating, note: note, for: aspiration)
                pulsedAspirations.insert(week.id)
            }
        }
    }

    func aspiration(for id: String) -> Aspiration? {
        aspirations.first { ($0.stableID?.uuidString ?? $0.title) == id }
    }
}

// MARK: - Decisions

/// The decision half of the intention lifecycle: closing and setting live at
/// the review; ticking lives on Today. Copy is factual throughout: no
/// automated praise, no automated disappointment.
extension WeeklyReviewView {
    /// Applies a row's closure decision to its intention.
    func handle(_ action: IntentionClosureAction, closureID: String) {
        guard let intention = intentions.first(where: { $0.stableID?.uuidString == closureID })
        else { return }
        switch action {
        case let .outcome(outcome):
            withAnimation { intention.close(outcome: outcome) }
        case .setAgain:
            withAnimation { modelContext.insert(IntentionRenewal.setAgain(intention)) }
        case let .acceptPromotion(promotion):
            accept(promotion, for: intention)
        case .declinePromotion:
            intention.promotionDismissed = true
        }
    }

    private func accept(_ promotion: IntentionPromotion, for intention: Intention) {
        switch promotion {
        case .weeklyGoal:
            guard let metric = intention.metric else { return }
            let prefill = intention.derivedMode == .valueSum ? intention.target : nil
            goalSettingsRoute = GoalSettingsRoute(metric: metric, prefillWeekly: prefill)
        case .dailyGoal:
            guard let metric = intention.metric else { return }
            goalSettingsRoute = GoalSettingsRoute(metric: metric, prefillWeekly: nil)
        case .countMetric:
            promote(intention, into: .count)
        case .binaryMetric:
            promote(intention, into: .binary)
        }
    }

    /// The counted promotions: a permanent metric named from the title,
    /// attached to the aspiration. The intention chain is left alone — ticks
    /// are never converted into sessions.
    private func promote(_ intention: Intention, into type: MeasurementType) {
        guard let aspiration = intention.aspiration else { return }
        let metric = Metric(
            name: intention.title,
            measurementType: type,
            colorName: MetricColor.nextAvailable(usedNames: metrics.map(\.colorName)).rawValue
        )
        withAnimation {
            modelContext.insert(metric)
            aspiration.metrics.append(metric)
        }
    }

    /// Upserts the current week's pulse: one row per aspiration per calendar
    /// week, the latest edit winning. Rating taps pass a nil note (leaving
    /// any typed note alone); the note field passes its text.
    func recordCheckIn(_ rating: AlignmentRating, note: String?, for aspiration: Aspiration) {
        if let existing = AspirationAlignment.currentWeekCheckIn(of: aspiration) {
            existing.ratingRaw = rating.rawValue
            if let note { existing.note = note }
            return
        }
        let checkIn = AspirationCheckIn(
            aspiration: aspiration,
            rating: rating,
            weekStart: Intention.weekStart(containing: .now),
            note: note ?? ""
        )
        modelContext.insert(checkIn)
    }
}

// MARK: - Closure row

/// One intention awaiting closure. The accumulation is shown as fact — no
/// judgment copy, no derived outcome label — and letting go sits visually
/// equal to every other decision.
struct IntentionClosureRow: View {
    let closure: WeeklyReview.IntentionClosure
    let act: (IntentionClosureAction) -> Void
    @State private var showingPromotion = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(closure.title)
                    .font(.subheadline)
                Spacer()
                if let progress = closure.progressText {
                    Text(progress)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                } else if closure.sourceRemoved {
                    Text("source removed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            decisions
        }
        .padding(.vertical, 2)
        .confirmationDialog(
            "Make it permanent?",
            isPresented: $showingPromotion,
            titleVisibility: .visible
        ) {
            promotionChoices
        } message: {
            Text("Set three weeks running. It can graduate into \(promotionDescription).")
        }
    }
}

// MARK: - Row pieces

extension IntentionClosureRow {
    private var decisions: some View {
        HStack(spacing: 8) {
            if closure.kind == .reflective {
                decisionButton("Done") { act(.outcome(.done)) }
                decisionButton("Partly") { act(.outcome(.partly)) }
            } else if !closure.sourceRemoved {
                decisionButton("Set Again") { act(.setAgain) }
                if closure.promotion != nil {
                    decisionButton("Promote") { showingPromotion = true }
                }
            }
            decisionButton("Let Go") { act(.outcome(.letGo)) }
        }
    }

    private func decisionButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ActionChip(voice: .decision(.accentColor)) {
                Text(label)
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var promotionChoices: some View {
        if let promotion = closure.promotion {
            Button(promotionLabel(promotion)) { act(.acceptPromotion(promotion)) }
        }
        Button("Not Now") { act(.declinePromotion) }
    }

    private func promotionLabel(_ promotion: IntentionPromotion) -> String {
        switch promotion {
        case .weeklyGoal: "Set a Weekly Goal"
        case .dailyGoal: "Set a Daily Goal"
        case .countMetric: "Create a Metric"
        case .binaryMetric: "Create a Daily Habit"
        }
    }

    private var promotionDescription: String {
        switch closure.promotion {
        case .weeklyGoal: "a weekly goal on its metric for a season"
        case .dailyGoal: "a daily goal on its metric for a season"
        case .countMetric: "a metric of its own"
        case .binaryMetric: "a daily habit of its own"
        case nil: ""
        }
    }
}

// MARK: - Pulse row

/// One aspiration's weekly alignment pulse: the three answers sitting
/// visually equal and — once one is chosen — room for a note.
struct AspirationPulseRow: View {
    let title: String
    let record: (AlignmentRating, String?) -> Void
    @State private var rating: AlignmentRating?
    @State private var note = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
            HStack(spacing: 8) {
                ForEach(AlignmentRating.allCases, id: \.rawValue) { option in
                    ratingChip(option)
                }
            }
            noteField
        }
        .padding(.vertical, 2)
    }

    private func ratingChip(_ option: AlignmentRating) -> some View {
        Button {
            rating = option
            record(option, nil)
        } label: {
            ActionChip(voice: rating == option ? .decision(.accentColor) : .quiet) {
                Text(option.shortLabel)
                    .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var noteField: some View {
        if rating != nil {
            TextField("Add a note (optional)", text: $note)
                .font(.caption)
                .textFieldStyle(.roundedBorder)
                .onSubmit(submitNote)
        }
    }

    private func submitNote() {
        guard let rating else { return }
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        record(rating, trimmed)
    }
}
