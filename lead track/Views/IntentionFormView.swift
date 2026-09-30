import SwiftData
import SwiftUI

/// The "Set an intention" sheet — a commitment for the week now underway,
/// always under one aspiration. Derived intentions choose among the metrics
/// already attached to that aspiration (so the week lens always nests inside
/// the lifetime lens), with a shortcut into the attach sheet to add more.
struct IntentionFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let aspiration: Aspiration

    @State private var title = ""
    @State private var kind: IntentionKind = .reflective
    @State private var metric: Metric?
    @State private var mode: DerivedMode = .sessionCount
    @State private var perDay = false
    @State private var targetCount = 3
    @State private var amountText = ""
    @State private var principle: Principle?
    @State private var showingAttach = false
    @State private var asksDaily = false
    @State private var question: IntentionQuestion = .makeDefault()

    /// Plain creation opens reflective and empty; the weekly review's
    /// intention asks seed the derived kind with the flagged metric
    /// preselected — same form, one prefilled doorway.
    init(aspiration: Aspiration, seedMetric: Metric? = nil) {
        self.aspiration = aspiration
        guard let seedMetric else { return }
        _kind = State(initialValue: .derived)
        _metric = State(initialValue: seedMetric)
    }

    var body: some View {
        NavigationStack {
            Form {
                if aspiration.isArchived {
                    Section {
                        Text("Bring this aspiration back before setting a new intention.")
                        AspirationShelvingControl(aspiration: aspiration)
                    }
                }
                IntentionTitleSection(title: $title, aspirationTitle: aspiration.title)
                IntentionKindSection(kind: $kind)
                if kind == .derived {
                    IntentionMetricSection(
                        aspiration: aspiration, metric: $metric, mode: $mode,
                        showingAttach: $showingAttach
                    )
                }
                if kind != .reflective {
                    IntentionShapeSection(
                        perDay: $perDay, targetCount: $targetCount, amountText: $amountText,
                        perDayAllowed: perDayAllowed, usesAmount: kind == .derived && mode == .valueSum,
                        amountUnit: amountUnit, countNoun: countNoun
                    )
                }
                IntentionDailyQuestionSection(asksDaily: $asksDaily, question: $question)
                if !aspiration.principles.isEmpty {
                    IntentionPrincipleSection(aspiration: aspiration, principle: $principle)
                }
            }
            .navigationTitle("Set an Intention")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            .sheet(isPresented: $showingAttach) {
                AspirationAttachSheet(aspiration: aspiration)
            }
            .onChange(of: kind) { resetShape() }
            .onChange(of: metric) { clampModeToMetric() }
            .onChange(of: mode) {
                if mode == .valueSum { perDay = false }
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .confirmationAction) {
            Button("Set", action: save)
                .disabled(!isValid)
        }
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { dismiss() }
        }
    }
}

private struct IntentionTitleSection: View {
    @Binding var title: String
    let aspirationTitle: String

    var body: some View {
        Section {
            TextField("What do you intend this week?", text: $title)
        } footer: {
            Text("Lives only this week, under \(aspirationTitle). It closes at the next weekly review.")
        }
    }
}

private struct IntentionKindSection: View {
    @Binding var kind: IntentionKind

    var body: some View {
        Section {
            Picker("Kind", selection: $kind) {
                Text("Reflective").tag(IntentionKind.reflective)
                Text("Counted").tag(IntentionKind.counted)
                Text("From a metric").tag(IntentionKind.derived)
            }
            .pickerStyle(.segmented)
        } footer: {
            Text(kindFooter)
        }
    }

    private var kindFooter: String {
        switch kind {
        case .reflective: "Held in the head, closed by one judgment at the review. No tracking of any kind."
        case .counted: "You tick it when it counted — your judgment is the filter."
        case .derived: "Accrues on its own from sessions you already log."
        }
    }
}

private struct IntentionMetricSection: View {
    let aspiration: Aspiration
    @Binding var metric: Metric?
    @Binding var mode: DerivedMode
    @Binding var showingAttach: Bool

    var body: some View {
        Section("Metric") {
            Picker("Metric", selection: $metric) {
                Text("Choose…").tag(Metric?.none)
                ForEach(aspiration.metrics.sorted { $0.createdAt < $1.createdAt }) { option in
                    Text(option.name).tag(Metric?.some(option))
                }
            }
            if metric?.measurementType.tracksQuantity == true {
                Picker("Counts", selection: $mode) {
                    Text("Sessions").tag(DerivedMode.sessionCount)
                    Text("Total amount").tag(DerivedMode.valueSum)
                }
            }
            Button("Attach another metric…") { showingAttach = true }
        }
    }
}

private struct IntentionShapeSection: View {
    @Binding var perDay: Bool
    @Binding var targetCount: Int
    @Binding var amountText: String
    let perDayAllowed: Bool
    let usesAmount: Bool
    let amountUnit: String
    let countNoun: String

    var body: some View {
        Section {
            if perDayAllowed {
                Toggle("Every day", isOn: $perDay)
            }
            if !perDay {
                if usesAmount {
                    HStack {
                        TextField(amountUnit, text: $amountText)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                        Text("\(amountUnit) / week")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Stepper(value: $targetCount, in: 1 ... 99) {
                        Text("\(targetCount) \(countNoun) / week")
                    }
                }
            }
        } footer: {
            if perDay {
                Text("Once a day counts, from today through the end of the week.")
            }
        }
    }
}

private struct IntentionPrincipleSection: View {
    let aspiration: Aspiration
    @Binding var principle: Principle?

    var body: some View {
        Section {
            Picker("Serves", selection: $principle) {
                Text("The why itself").tag(Principle?.none)
                ForEach(aspiration.principles.sorted { $0.createdAt < $1.createdAt }) { held in
                    Text(held.text).tag(Principle?.some(held))
                }
            }
        } footer: {
            Text("The principle this intention lives out, if it names one.")
        }
    }
}

// MARK: - Draft & save

extension IntentionFormView {
    private var perDayAllowed: Bool {
        kind == .counted || (kind == .derived && mode == .sessionCount)
    }

    private var countNoun: String {
        if kind == .counted { return targetCount == 1 ? "time" : "times" }
        return targetCount == 1 ? "session" : "sessions"
    }

    private var amountUnit: String {
        metric?.measurementType == .count ? (metric?.unit ?? "count") : "h"
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Checked without constructing a model — the same rules `Intention.make`
    /// enforces on save, plus a switched-on question needing words.
    private var isValid: Bool {
        !aspiration.isArchived && !trimmedTitle.isEmpty
            && (!asksDaily || !question.trimmedText.isEmpty)
            && Intention.isValidShape(
                kind: kind,
                derivedMode: kind == .derived ? mode : nil,
                metric: kind == .derived ? metric : nil,
                perDay: perDay,
                target: storedTarget
            )
    }

    private var storedTarget: Double? {
        guard kind != .reflective, !perDay else { return nil }
        if kind == .derived, mode == .valueSum {
            guard let amount = LocaleDoubleParser.parse(amountText), amount > 0 else { return nil }
            // The weekly-goal convention: duration targets are edited in
            // hours and stored in seconds (see GoalUnit).
            guard let type = metric?.measurementType else { return amount }
            return GoalUnit.weekly(type).stored(fromDisplay: amount)
        }
        return Double(targetCount)
    }

    private func save() {
        guard !aspiration.isArchived else { return }
        guard let intention = try? Intention.make(
            title: trimmedTitle,
            kind: kind,
            aspiration: aspiration,
            derivedMode: kind == .derived ? mode : nil,
            metric: kind == .derived ? metric : nil,
            perDay: perDay,
            target: storedTarget
        ) else { return }
        intention.principle = principle
        intention.applyQuestion(asksDaily ? question : nil)
        modelContext.insert(intention)
        NotificationService.scheduleQuestion(for: intention)
        dismiss()
    }

    private func resetShape() {
        perDay = false
        if kind != .derived {
            metric = nil
        }
    }

    /// Binary metrics track no quantity, so a value-sum mode quietly snaps
    /// back to counting sessions.
    private func clampModeToMetric() {
        if metric?.measurementType.tracksQuantity != true {
            mode = .sessionCount
        }
    }
}
