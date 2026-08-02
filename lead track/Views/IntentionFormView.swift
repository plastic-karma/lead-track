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
                titleSection
                kindSection
                if kind == .derived {
                    metricSection
                }
                shapeSection
                questionSection
                if !heldPrinciples.isEmpty {
                    servesSection
                }
            }
            .navigationTitle("Set an Intention")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Set", action: save)
                        .disabled(!isValid)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
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
}

// MARK: - Sections

extension IntentionFormView {
    private var titleSection: some View {
        Section {
            TextField("What do you intend this week?", text: $title)
        } footer: {
            Text("Lives only this week, under \(aspiration.title). It closes at the next weekly review.")
        }
    }

    private var kindSection: some View {
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

    private var metricSection: some View {
        Section("Metric") {
            Picker("Metric", selection: $metric) {
                Text("Choose…").tag(Metric?.none)
                ForEach(attachedMetrics) { option in
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

    @ViewBuilder
    private var shapeSection: some View {
        if kind != .reflective {
            Section {
                if perDayAllowed {
                    Toggle("Every day", isOn: $perDay)
                }
                if !perDay {
                    targetField
                }
            } footer: {
                if perDay {
                    Text("Once a day counts, from today through the end of the week.")
                }
            }
        }
    }

    private var questionSection: some View {
        Section {
            Toggle("Daily Question", isOn: $asksDaily)
            if asksDaily {
                IntentionQuestionEditor(question: $question)
            }
        } footer: {
            if asksDaily {
                Text("Asks once a day, at a random time inside your window, through the end of the week.")
            }
        }
    }

    /// Present only once the aspiration holds any principles — the why
    /// threaded through the commitment, never a required field.
    private var servesSection: some View {
        Section {
            Picker("Serves", selection: $principle) {
                Text("The why itself").tag(Principle?.none)
                ForEach(heldPrinciples) { held in
                    Text(held.text).tag(Principle?.some(held))
                }
            }
        } footer: {
            Text("The principle this intention lives out, if it names one.")
        }
    }

    @ViewBuilder
    private var targetField: some View {
        if kind == .derived, mode == .valueSum {
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
}

// MARK: - Draft & save

extension IntentionFormView {
    private var attachedMetrics: [Metric] {
        aspiration.metrics.sorted { $0.createdAt < $1.createdAt }
    }

    private var heldPrinciples: [Principle] {
        aspiration.principles.sorted { $0.createdAt < $1.createdAt }
    }

    private var perDayAllowed: Bool {
        kind == .counted || (kind == .derived && mode == .sessionCount)
    }

    private var countNoun: String {
        kind == .counted ? "times" : "sessions"
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
        !trimmedTitle.isEmpty
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
