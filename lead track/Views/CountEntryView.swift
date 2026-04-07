import SwiftUI

struct CountEntryView: View {
    let metric: Metric
    let project: Project?
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var valueText = ""
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
                    if let unit = metric.unit, !unit.isEmpty {
                        Text("Enter number of \(unit)")
                    }
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
        }
    }

    private var parsedValue: Double? {
        Double(valueText).flatMap { $0 > 0 ? $0 : nil }
    }

    private func save() {
        guard let value = parsedValue else { return }
        SessionService.logCount(
            value,
            for: metric,
            project: project,
            in: modelContext
        )
        dismiss()
    }
}
