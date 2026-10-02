import SwiftData
import SwiftUI

/// One persisted action shared by the detail and any already-open composer.
struct AspirationShelvingControl: View {
    @Environment(\.modelContext) private var modelContext
    let aspiration: Aspiration
    @State private var showingConfirmation = false
    @State private var saveError: String?

    var body: some View {
        Button(aspiration.isArchived ? "Bring back" : "Set aside", systemImage: "archivebox") {
            if aspiration.isArchived {
                changeShelving(false)
            } else {
                showingConfirmation = true
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .confirmationDialog(
            "Set aside \(aspiration.title)?",
            isPresented: $showingConfirmation,
            titleVisibility: .visible
        ) {
            Button("Set aside") { changeShelving(true) }
        } message: {
            Text(confirmationMessage)
        }
        .alert("Couldn't save aspiration", isPresented: errorPresented) {
            Button("OK", role: .cancel) { saveError = nil }
        } message: {
            Text(saveError ?? "")
        }
    }

    private var confirmationMessage: String {
        """
        Its history and attachments stay intact. Metrics keep running under another active aspiration \
        or Unaligned Effort; setting aside metrics is a separate action. This week's intentions and \
        last week's closures remain available. No new check-ins or daily questions are asked while \
        it is set aside. Bring it back whenever you want, without an overdue queue.
        """
    }

    private var errorPresented: Binding<Bool> {
        Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })
    }

    private func changeShelving(_ archived: Bool) {
        do {
            // Resolve the forward relationship before saving: inverse arrays
            // are not reliably populated in this store.
            let intentions = try modelContext.fetch(FetchDescriptor<Intention>())
                .filter { $0.aspiration === aspiration }
            try AspirationShelving.setArchived(archived, for: aspiration) {
                try modelContext.save()
            }
            for intention in intentions {
                NotificationService.rescheduleQuestion(for: intention)
            }
        } catch {
            saveError = error.localizedDescription
        }
    }
}

/// A deliberate library doorway, not an active-work queue.
struct SetAsideAspirationsView: View {
    @Query(sort: \Aspiration.createdAt) private var aspirations: [Aspiration]

    private var shelved: [Aspiration] {
        aspirations.filter(\.isArchived).inDisplayOrder
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(shelved) { aspiration in
                    NavigationLink(value: aspiration) {
                        AspirationCardView(aspiration: aspiration)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: 680)
            .frame(maxWidth: .infinity)
            .padding()
        }
        .background(Theme.washedScreen)
        .navigationTitle("Set-aside aspirations")
        .overlay {
            if shelved.isEmpty {
                ContentUnavailableView(
                    "Nothing set aside", systemImage: "archivebox",
                    description: Text("Aspirations you set aside stay here with their history intact.")
                )
            }
        }
    }
}
