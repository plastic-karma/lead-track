import SwiftUI

/// The action rows shared by intention creation and post-creation editing.
/// They are calendar blocks only: no checkbox, status, reminder, or overdue
/// state is introduced back into LeadStone.
struct IntentionActionsEditor: View {
    @Binding var actions: [IntentionActionDraft]
    let week: DateInterval

    var body: some View {
        ForEach($actions) { $action in
            IntentionActionEditorRow(action: $action, week: week) {
                remove(action.id)
            }
        }
        Button(action: addAction) {
            Label("Add an Action", systemImage: "plus.circle")
        }
    }

    private func addAction() {
        let previousEnd = actions.map(\.endsAt).max()
        actions.append(.makeDefault(in: week, after: previousEnd))
    }

    private func remove(_ id: UUID) {
        actions.removeAll { $0.id == id }
    }
}

private struct IntentionActionEditorRow: View {
    @Binding var action: IntentionActionDraft
    let week: DateInterval
    let remove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("What will you do?", text: $action.title, axis: .vertical)
            DatePicker(
                "Starts",
                selection: startsAt,
                in: startRange,
                displayedComponents: [.date, .hourAndMinute]
            )
            DatePicker(
                "Ends",
                selection: $action.endsAt,
                in: endRange,
                displayedComponents: [.date, .hourAndMinute]
            )
            Button("Remove Action", systemImage: "minus.circle", role: .destructive) {
                remove()
            }
            .font(.caption)
            .frame(minHeight: 44, alignment: .leading)
            .accessibilityLabel(removeAccessibilityLabel)
        }
        .padding(.vertical, 4)
    }

    /// Moving the start keeps the intended duration whenever the remainder of
    /// the week allows it, instead of leaving an invalid end behind.
    private var startsAt: Binding<Date> {
        Binding(
            get: { action.startsAt },
            set: { newValue in
                let duration = max(
                    action.endsAt.timeIntervalSince(action.startsAt),
                    IntentionActionDraft.minimumDuration
                )
                action.startsAt = newValue
                action.endsAt = min(newValue.addingTimeInterval(duration), week.end)
            }
        )
    }

    private var startRange: ClosedRange<Date> {
        week.start ... week.end.addingTimeInterval(-IntentionActionDraft.minimumDuration)
    }

    private var endRange: ClosedRange<Date> {
        let latestStart = week.end.addingTimeInterval(-IntentionActionDraft.minimumDuration)
        let safeStart = min(max(action.startsAt, week.start), latestStart)
        return safeStart.addingTimeInterval(IntentionActionDraft.minimumDuration) ... week.end
    }

    private var removeAccessibilityLabel: String {
        let title = action.trimmedTitle
        return title.isEmpty ? "Remove untitled action" : "Remove \(title)"
    }
}
