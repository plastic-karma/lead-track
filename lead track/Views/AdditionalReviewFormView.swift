import SwiftUI

struct AdditionalReviewFormView: View {
    @Environment(\.dismiss) private var dismiss

    private let original: AdditionalReview?
    private let save: (AdditionalReview) -> Void

    @State private var name: String
    @State private var cycle: AdditionalReviewCycleKind
    @State private var customUnit: AdditionalReviewCycleUnit
    @State private var customInterval: Int
    @State private var hour: Int
    @State private var minute: Int

    init(
        review: AdditionalReview? = nil,
        save: @escaping (AdditionalReview) -> Void
    ) {
        original = review
        self.save = save
        _name = State(initialValue: review?.name ?? "")
        _cycle = State(initialValue: review?.cycle ?? .monthly)
        _customUnit = State(initialValue: review?.customUnit ?? .days)
        _customInterval = State(initialValue: review?.customInterval ?? 10)
        _hour = State(initialValue: review?.hour ?? 9)
        _minute = State(initialValue: review?.minute ?? 0)
    }

    var body: some View {
        NavigationStack {
            form
        }
    }

    private var form: some View {
        Form {
            reviewSection
            if cycle == .custom {
                customCycleSection
            }
            notificationSection
        }
        .navigationTitle(original == nil ? "Add Review" : "Edit Review")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarItems }
    }

    private var reviewSection: some View {
        Section("Review") {
            TextField("Name", text: $name)
            cyclePicker
        }
    }

    private var notificationSection: some View {
        Section("Notification") {
            DatePicker(
                "Time",
                selection: timeBinding,
                displayedComponents: .hourAndMinute
            )
        } footer: {
            Text(nextReviewDescription)
        }
    }

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("Save") { commit() }
                .disabled(trimmedName.isEmpty)
        }
    }

    private var cyclePicker: some View {
        Picker("Cycle", selection: $cycle) {
            Text("Monthly").tag(AdditionalReviewCycleKind.monthly)
            Text("Quarterly").tag(AdditionalReviewCycleKind.quarterly)
            Text("Yearly").tag(AdditionalReviewCycleKind.yearly)
            Text("Custom").tag(AdditionalReviewCycleKind.custom)
        }
    }

    private var customCycleSection: some View {
        Section("Custom Cycle") {
            Picker("Unit", selection: $customUnit) {
                Text("Days").tag(AdditionalReviewCycleUnit.days)
                Text("Months").tag(AdditionalReviewCycleUnit.months)
            }
            .pickerStyle(.segmented)
            Stepper(
                customIntervalLabel,
                value: $customInterval,
                in: 1 ... customUnit.maximumInterval
            )
        } footer: {
            Text("The first review arrives when this complete period ends.")
        }
        .onChange(of: customUnit) {
            customInterval = min(customInterval, customUnit.maximumInterval)
        }
    }

    private var customIntervalLabel: String {
        let unit = customUnit == .days ? "day" : "month"
        return "Every \(customInterval) \(unit)\(customInterval == 1 ? "" : "s")"
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var nextReviewDescription: String {
        let next = AdditionalReviewSchedule.nextReviewDate(for: draft)
        return "Next review: \(next.formatted(date: .abbreviated, time: .shortened)). "
            + "It will total the completed period ending that day."
    }

    private var timeBinding: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(
                    from: DateComponents(hour: hour, minute: minute)
                ) ?? .now
            },
            set: { date in
                let components = Calendar.current.dateComponents([.hour, .minute], from: date)
                hour = components.hour ?? 9
                minute = components.minute ?? 0
            }
        )
    }

    private var draft: AdditionalReview {
        AdditionalReview(
            id: original?.id ?? UUID(),
            name: trimmedName,
            cycle: cycle,
            customUnit: customUnit,
            customInterval: customInterval,
            anchor: resolvedAnchor,
            hour: hour,
            minute: minute,
            createdAt: original?.createdAt ?? .now
        )
    }

    private var resolvedAnchor: Date {
        guard let original, !cadenceChanged(from: original) else {
            return Calendar.current.startOfDay(for: .now)
        }
        return original.anchor
    }

    private func cadenceChanged(from review: AdditionalReview) -> Bool {
        cycle != review.cycle
            || customUnit != review.customUnit
            || customInterval != review.customInterval
    }

    private func commit() {
        save(draft)
        dismiss()
    }
}
