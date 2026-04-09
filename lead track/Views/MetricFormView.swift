import SwiftData
import SwiftUI

struct MetricFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query private var existingMetrics: [Metric]
    @State private var name = ""
    @State private var icon = "clock"
    @State private var measurementType: MeasurementType = .duration
    @State private var unit = ""

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
                Section {
                    TextField("Name", text: $name)
                    if nameIsDuplicate {
                        Text("A metric with this name already exists.")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                typePicker
                iconPicker
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
            iconGrid
        }
    }

    private var iconGrid: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 44))],
            spacing: 12
        ) {
            ForEach(iconOptions, id: \.self) { option in
                iconButton(option)
            }
        }
    }

    private func iconButton(_ option: String) -> some View {
        Button {
            icon = option
        } label: {
            Image(systemName: option)
                .font(.title2)
                .frame(width: 44, height: 44)
                .background(
                    icon == option
                        ? Color.accentColor.opacity(0.2)
                        : Color.clear
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private func save() {
        let metric = Metric(
            name: name,
            measurementType: measurementType,
            unit: measurementType == .count ? unit : nil,
            icon: icon
        )
        modelContext.insert(metric)
        dismiss()
    }
}
