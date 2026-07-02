import SwiftData
import SwiftUI

/// The route an accepted goal promotion opens: the existing goal-settings
/// sheet for the linked metric, prefilled from the intention's target when
/// the units line up (a value-sum target is already in the metric's native
/// unit; a session count is not an amount, so the user picks one).
struct PromotionGoalRoute: Identifiable {
    let id = UUID()
    let metric: Metric
    let prefillWeekly: Double?
}

/// A closure decision made on one review row.
enum IntentionClosureAction {
    case outcome(IntentionOutcome)
    case setAgain
    case acceptPromotion(IntentionPromotion)
    case declinePromotion
}

// MARK: - Decisions

/// The decision half of the intention lifecycle: the closure choices made on
/// an aspiration's card write back through here — closing and setting live at
/// the review; ticking lives on Today. Copy is factual throughout: no
/// automated praise, no automated disappointment.
extension WeeklyReviewView {
    /// Applies a card's closure decision to its intention. Internal (not
    /// private) because the rows live on the aspiration cards in their own
    /// file.
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
            promotionGoal = PromotionGoalRoute(metric: metric, prefillWeekly: prefill)
        case .dailyGoal:
            guard let metric = intention.metric else { return }
            promotionGoal = PromotionGoalRoute(metric: metric, prefillWeekly: nil)
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
            Text(label)
                .font(.caption.weight(.medium))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
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
        case .weeklyGoal: "a weekly goal on its metric"
        case .dailyGoal: "a daily goal on its metric"
        case .countMetric: "a metric of its own"
        case .binaryMetric: "a daily habit of its own"
        case nil: ""
        }
    }
}
