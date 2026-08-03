import SwiftData
import SwiftUI

/// Edits one live intention's concrete calendar commitments, or reviews a past
/// intention without reopening it. Editing uses local drafts so Cancel is real;
/// Save reconciles by stable action ID.
struct IntentionActionsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let intention: Intention
    let allowsEditing: Bool
    @Query private var storedActions: [IntentionAction]
    @State private var actions: [IntentionActionDraft] = []
    @State private var hasLoaded = false
    @State private var saveFailed = false
    @State private var exportFailed = false
    @State private var calendarURL: URL?

    init(intention: Intention, allowsEditing: Bool = true) {
        self.intention = intention
        self.allowsEditing = allowsEditing
        let intentionID = intention.stableID ?? UUID()
        _storedActions = Query(
            filter: #Predicate<IntentionAction> { $0.intentionID == intentionID },
            sort: \.startsAt
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                actionsSection
                if !actions.isEmpty {
                    calendarSection
                }
            }
            .navigationTitle("Scheduled Actions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarButtons }
            .alert("Couldn't Save Actions", isPresented: $saveFailed) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Your changes couldn't be saved. Try again.")
            }
            .alert("Couldn't Create Calendar File", isPresented: $exportFailed) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Free up space and try again.")
            }
        }
        .onAppear(perform: loadOnce)
        .onChange(of: actions) { calendarURL = nil }
        .presentationDetents([.large])
    }
}

// MARK: - Sections

private extension IntentionActionsSheet {
    var actionsSection: some View {
        Section {
            if allowsEditing {
                IntentionActionsEditor(actions: $actions, week: intention.weekInterval())
            } else if actions.isEmpty {
                Text("No scheduled actions were kept.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(actions) { action in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(action.trimmedTitle)
                        Text(actionRange(action))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            }
        } footer: {
            Text(actionsFooter)
        }
    }

    var calendarSection: some View {
        Section {
            if let url = calendarURL {
                ShareLink(
                    item: url,
                    preview: SharePreview(
                        IntentionCalendarExporter.filename(intentionTitle: intention.title)
                    )
                ) {
                    Label("Add to Calendar (.ics)", systemImage: "calendar.badge.plus")
                }
            }
            Button(calendarPreparationLabel, action: prepareCalendar)
                .disabled(normalizedActions?.isEmpty != false)
            if normalizedActions == nil {
                Text("Give every action a title, start, and later end time.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Calendar File")
        } footer: {
            Text("Calendar receives a copy. Later edits in LeadStone do not change events already added.")
        }
    }

    @ToolbarContentBuilder var toolbarButtons: some ToolbarContent {
        if allowsEditing {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
                    .disabled(normalizedActions == nil)
            }
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        } else {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
    }
}

// MARK: - Data

private extension IntentionActionsSheet {
    var normalizedActions: [IntentionActionDraft]? {
        if allowsEditing {
            return IntentionActionDraft.validated(
                actions,
                in: intention.weekInterval()
            )
        }
        return IntentionActionDraft.validated(actions)
    }

    func loadOnce() {
        guard !hasLoaded else { return }
        let storedDrafts = storedActions.map(\.draft)
        if allowsEditing {
            let week = intention.weekInterval()
            actions = storedDrafts.map { $0.clamped(in: week) }
        } else {
            actions = storedDrafts
        }
        hasLoaded = true
    }

    func save() {
        do {
            try persistActions()
            dismiss()
        } catch {
            StoreLog.error("Intention action save failed: \(error)")
            saveFailed = true
        }
    }

    func prepareCalendar() {
        guard let normalizedActions, !normalizedActions.isEmpty else { return }
        do {
            if allowsEditing {
                try persistActions()
            }
            guard let url = IntentionCalendarExporter.exportFile(
                intentionTitle: intention.title,
                aspirationTitle: intention.aspiration?.title,
                actions: normalizedActions
            ) else {
                exportFailed = true
                return
            }
            calendarURL = url
        } catch {
            StoreLog.error("Intention action save before export failed: \(error)")
            saveFailed = true
        }
    }

    func persistActions() throws {
        guard let intentionID = intention.stableID,
              let normalizedActions
        else { throw IntentionActionStoreError.invalidDrafts }
        try modelContext.transaction {
            try modelContext.replaceIntentionActions(
                for: intentionID,
                with: normalizedActions
            )
        }
    }

    var actionsFooter: String {
        if allowsEditing {
            return "Optional calendar blocks for this intention. They are not tracked or checked off."
        }
        return "Past intentions are final. You can review or export these calendar blocks, but not edit them."
    }

    var calendarPreparationLabel: String {
        allowsEditing ? "Save & Prepare Calendar File" : "Prepare Calendar File"
    }

    func actionRange(_ action: IntentionActionDraft) -> String {
        action.startsAt.formatted(date: .abbreviated, time: .shortened)
            + " – "
            + action.endsAt.formatted(date: .abbreviated, time: .shortened)
    }
}
