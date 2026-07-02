import SwiftData
import SwiftUI

/// Creates a new metric, or edits an existing one when handed a `metric`.
/// Editing leaves the measurement type fixed — sessions are already recorded
/// against it — while name, description, icon, unit, and color stay editable.
/// Health-linked metrics keep their source fixed too, and access to the one
/// Apple Health figure they mirror is requested only when they are saved —
/// never up front.
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
    @State private var kind: MetricFormKind
    @State private var healthSource: HealthDataSource
    @State private var healthExport: HealthExportTarget?
    @State private var unit: String
    @State private var saveTrigger = false

    init(metric: Metric? = nil) {
        editingMetric = metric
        _name = State(initialValue: metric?.name ?? "")
        _details = State(initialValue: metric?.metricDescription ?? "")
        _icon = State(initialValue: metric?.icon ?? "clock")
        let storedColor = metric?.colorName.flatMap(MetricColor.init(rawValue:))
        _color = State(initialValue: storedColor ?? .copper)
        _kind = State(initialValue: MetricFormKind(metric: metric))
        _healthSource = State(initialValue: metric?.healthSource ?? .activeCalories)
        _healthExport = State(initialValue: metric?.healthExportTarget)
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
                healthExportSection
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
            .onChange(of: kind) { _, newKind in
                adjustIcon(forKind: newKind)
            }
            .onChange(of: healthSource) { _, newSource in
                icon = newSource.defaultIcon
            }
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

    /// Health sources carry a matching icon, so picking Health preselects it;
    /// leaving Health restores a neutral default when a health-only icon was
    /// still selected.
    private func adjustIcon(forKind newKind: MetricFormKind) {
        if newKind == .health {
            icon = healthSource.defaultIcon
        } else if !iconOptions.contains(icon) {
            icon = "clock"
        }
    }

    private func save() {
        let metric = editingMetric ?? newMetric()
        let previousExport = metric.healthExportRaw
        apply(to: metric)
        if editingMetric == nil {
            modelContext.insert(metric)
            connectHealthIfNeeded(metric)
        }
        if metric.healthExportRaw != previousExport, metric.healthExportTarget != nil {
            connectHealthExport(metric)
        }
        saveTrigger.toggle()
        dismiss()
    }

    /// A fresh metric of the chosen kind. Health metrics derive measurement
    /// type and unit from their source so mirrored values display right.
    private func newMetric() -> Metric {
        if kind == .health {
            return Metric(
                name: name,
                measurementType: healthSource.measurementType,
                unit: healthSource.defaultUnit,
                healthSource: healthSource
            )
        }
        return Metric(name: name, measurementType: kind.measurementType ?? .duration)
    }

    /// Writes the form's editable fields onto the metric. The measurement
    /// type and health source are intentionally left untouched: they come
    /// from the initializer on create and stay locked on edit.
    private func apply(to metric: Metric) {
        metric.name = name
        metric.metricDescription = Metric.normalizedDescription(details)
        metric.icon = icon
        metric.colorName = color.rawValue
        if !metric.isHealthLinked {
            metric.unit = kind == .count ? unit : nil
        }
        if metric.supportsHealthExport {
            metric.setHealthExport(healthExport)
        }
    }

    /// First save of a health metric: persist it, then ask to read its one
    /// source and backfill the mirror — the only moment LeadStone ever
    /// requests Health access.
    private func connectHealthIfNeeded(_ metric: Metric) {
        guard metric.isHealthLinked, let id = metric.stableID else { return }
        try? modelContext.save()
        let container = modelContext.container
        Task {
            await HealthMetricSyncService.shared.connect(
                metricID: id, container: container
            )
        }
    }

    /// A save that switches export on (or to another record type) persists
    /// the metric, asks to write that one type, and sends what's pending.
    private func connectHealthExport(_ metric: Metric) {
        guard let id = metric.stableID else { return }
        try? modelContext.save()
        let container = modelContext.container
        Task {
            await HealthSessionExportService.shared.connect(
                metricID: id, container: container
            )
        }
    }
}

// MARK: - Sections

extension MetricFormView {
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
            Picker("Measurement", selection: $kind) {
                Text("Duration").tag(MetricFormKind.duration)
                Text("Count").tag(MetricFormKind.count)
                Text("Yes/No").tag(MetricFormKind.binary)
                if showsHealthOption {
                    Text("Health").tag(MetricFormKind.health)
                }
            }
            .pickerStyle(.segmented)
            .disabled(isEditing)
            if kind == .count {
                TextField(
                    "Unit (e.g. pages, calls)",
                    text: $unit
                )
            }
            if kind == .health {
                healthSourceRow
            }
        } header: {
            Text("Type")
        } footer: {
            typeFooter
        }
    }

    /// The Health segment appears only on devices with health data — and
    /// always when reopening an existing health metric, so the fixed
    /// selection still renders.
    private var showsHealthOption: Bool {
        kind == .health
            || (!isEditing && HealthMetricSyncService.shared.isAvailable)
    }

    /// Export is offered for timer metrics on devices with health data — and
    /// always when it is already on, so the stored choice still renders.
    @ViewBuilder
    private var healthExportSection: some View {
        if kind == .duration, healthExport != nil || HealthSessionExportService.shared.isAvailable {
            MetricFormHealthExportSection(selection: $healthExport)
        }
    }

    private var healthSourceRow: some View {
        Picker("Source", selection: $healthSource) {
            ForEach(HealthDataSource.allCases, id: \.self) { source in
                Text(source.displayName).tag(source)
            }
        }
        .disabled(isEditing)
    }

    @ViewBuilder
    private var typeFooter: some View {
        if isEditing {
            Text("The measurement type is fixed once a metric is created.")
        } else if kind == .binary {
            Text("Tracks whether you did it each day — done or not, no amount.")
        } else if kind == .health {
            Text(healthFooter)
        }
    }

    private var healthFooter: String {
        healthSource.explanation
            + " LeadStone will ask to read only this from Apple Health when you save."
            + " Nothing is written back, and you can change access anytime in the Health app."
    }

    private var iconPicker: some View {
        Section("Icon") {
            IconGridPicker(options: iconChoices, selection: $icon)
        }
    }

    /// Health metrics lead with icons matching the health sources; the other
    /// kinds keep the standard set.
    private var iconChoices: [String] {
        guard kind == .health else { return iconOptions }
        let healthIcons = HealthDataSource.allCases.map(\.defaultIcon)
        return healthIcons + iconOptions.filter { !healthIcons.contains($0) }
    }

    private var colorPicker: some View {
        Section("Color") {
            ColorGridPicker(selection: $color)
        }
    }
}
