import SwiftData
import SwiftUI

struct MetricFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query private var existingMetrics: [Metric]
    @State private var name = ""
    @State private var icon = "clock"
    @State private var color: MetricColor = .copper
    @State private var didSuggestColor = false
    @State private var measurementType: MeasurementType = .duration
    @State private var unit = ""
    @State private var saveTrigger = false

    private var nameIsDuplicate: Bool {
        existingMetrics.contains {
            $0.name.lowercased() == name.lowercased()
        }
    }

    private let iconOptions = [
        "clock", "book", "laptopcomputer",
        "figure.run", "pencil", "music.note",
        "paintbrush", "hammer", "gamecontroller"
    ]

    var body: some View {
        NavigationStack {
            Form {
                nameSection
                typePicker
                iconPicker
                colorPicker
            }
            .navigationTitle("New Metric")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(name.isEmpty || nameIsDuplicate)
                }
            }
            .sensoryFeedback(.success, trigger: saveTrigger)
            .onAppear(perform: suggestColor)
        }
    }

    /// Preselects the least-used identity color so metrics differentiate
    /// themselves on the dashboard without the user having to think about it.
    private func suggestColor() {
        guard !didSuggestColor else { return }
        didSuggestColor = true
        color = MetricColor.nextAvailable(
            usedNames: existingMetrics.map(\.colorName)
        )
    }

    private var nameSection: some View {
        Section {
            TextField("Name", text: $name)
            if nameIsDuplicate {
                Text("A metric with this name already exists.")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private var typePicker: some View {
        Section("Type") {
            Picker("Measurement", selection: $measurementType) {
                Text("Duration").tag(MeasurementType.duration)
                Text("Count").tag(MeasurementType.count)
            }
            .pickerStyle(.segmented)
            if measurementType == .count {
                TextField(
                    "Unit (e.g. pages, calls)",
                    text: $unit
                )
            }
        }
    }

    private var iconPicker: some View {
        Section("Icon") {
            IconGridPicker(options: iconOptions, selection: $icon)
        }
    }

    private var colorPicker: some View {
        Section("Color") {
            ColorGridPicker(selection: $color)
        }
    }

    private func save() {
        let metric = Metric(
            name: name,
            measurementType: measurementType,
            unit: measurementType == .count ? unit : nil,
            icon: icon,
            colorName: color.rawValue
        )
        modelContext.insert(metric)
        saveTrigger.toggle()
        dismiss()
    }
}
