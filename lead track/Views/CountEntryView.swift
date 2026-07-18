import SwiftUI

struct CountEntryView: View {
    let metric: Metric
    let project: Project?
    /// The instant the log lands on — nil logs at the moment of saving (the
    /// living today); the Today rows pass a browsed earlier day's instant so
    /// the amount writes into that day.
    var day: Date?
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var valueText = ""
    @State private var saveTrigger = false
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(
                        "Value",
                        text: $valueText
                    )
                    .keyboardType(.decimalPad)
                    .focused($isFocused)
                } footer: {
                    footer
                }
            }
            .navigationTitle("Log \(metric.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(parsedValue == nil)
                }
            }
            .onAppear { isFocused = true }
            .sensoryFeedback(.success, trigger: saveTrigger)
        }
    }

    /// The unit reminder, joined — on a browsed earlier day — by which day
    /// the log lands on, so backfilling never writes into today unnoticed.
    private var footer: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let unit = metric.unit, !unit.isEmpty {
                Text("Enter number of \(unit)")
            }
            if let day {
                Text("Logs to \(day.formatted(.dateTime.weekday(.wide).month(.wide).day()))")
            }
        }
    }

    private var parsedValue: Double? {
        LocaleDoubleParser.parse(valueText).flatMap { $0 > 0 ? $0 : nil }
    }

    private func save() {
        guard let value = parsedValue else { return }
        SessionService.logCount(
            value,
            for: metric,
            project: project,
            in: modelContext,
            at: day ?? .now
        )
        saveTrigger.toggle()
        dismiss()
    }
}
