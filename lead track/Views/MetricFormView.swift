import SwiftData
import SwiftUI

/// Creates a new metric, or edits an existing one when handed a `metric`.
/// Editing leaves the measurement type fixed — sessions are already recorded
/// against it — while name, description, icon, unit, and color stay editable.
struct MetricFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query private var existingMetrics: [Metric]
    private let editingMetric: Metric?
    @State private var name: String
    @State private var details: String
    @State private var icon: String
    @State private var color: MetricColor
    @State private var didSuggestColor = false
    @State private var measurementType: MeasurementType
    @State private var unit: String
    @State private var saveTrigger = false

    init(metric: Metric? = nil) {
        editingMetric = metric
        _name = State(initialValue: metric?.name ?? "")
        _details = State(initialValue: metric?.metricDescription ?? "")
        _icon = State(initialValue: metric?.icon ?? "clock")
        let storedColor = metric?.colorName.flatMap(MetricColor.init(rawValue:))
        _color = State(initialValue: storedColor ?? .copper)
        _measurementType = State(initialValue: metric?.measurementType ?? .duration)
        _unit = State(initialValue: metric?.unit ?? "")
    }

    private var isEditing: Bool {
        editingMetric != nil
    }

    private var formTitle: String {
        isEditing ? "Edit Metric" : "New Metric"
    }

    private var nameIsDuplicate: Bool {
        let target = name.lowercased()
        return existingMetrics.contains {
            $0.persistentModelID != editingMetric?.persistentModelID && $0.name.lowercased() == target
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
                descriptionSection
                typePicker
                iconPicker
                colorPicker
            }
            .navigationTitle(formTitle)
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
    /// Only for new metrics — editing keeps whatever color was chosen.
    private func suggestColor() {
        guard !isEditing, !didSuggestColor else { return }
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

    private var descriptionSection: some View {
        Section("Description") {
            TextField("Optional description", text: $details, axis: .vertical)
                .lineLimit(1 ... 4)
        }
    }

    private var typePicker: some View {
        Section {
            Picker("Measurement", selection: $measurementType) {
                Text("Duration").tag(MeasurementType.duration)
                Text("Count").tag(MeasurementType.count)
                Text("Yes/No").tag(MeasurementType.binary)
            }
            .pickerStyle(.segmented)
            .disabled(isEditing)
            if measurementType == .count {
                TextField(
                    "Unit (e.g. pages, calls)",
                    text: $unit
                )
            }
        } header: {
            Text("Type")
        } footer: {
            typeFooter
        }
    }

    @ViewBuilder
    private var typeFooter: some View {
        if isEditing {
            Text("The measurement type is fixed once a metric is created.")
        } else if measurementType == .binary {
            Text("Tracks whether you did it each day — done or not, no amount.")
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
        let metric = editingMetric ?? Metric(name: name, measurementType: measurementType)
        apply(to: metric)
        if editingMetric == nil {
            modelContext.insert(metric)
        }
        saveTrigger.toggle()
        dismiss()
    }

    /// Writes the form's editable fields onto the metric. The measurement type
    /// is intentionally left untouched: it comes from the initializer on create
    /// and stays locked on edit.
    private func apply(to metric: Metric) {
        metric.name = name
        metric.metricDescription = Metric.normalizedDescription(details)
        metric.icon = icon
        metric.colorName = color.rawValue
        metric.unit = measurementType == .count ? unit : nil
    }
}
