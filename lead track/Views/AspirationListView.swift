import SwiftData
import SwiftUI

/// The Aspirations tab: a scrolling list of aspiration cards, each a lens over
/// the effort poured into its attached metrics and projects. A peer of the
/// Today dashboard; an app with no aspirations shows a friendly empty state.
struct AspirationListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Aspiration.createdAt) private var aspirations: [Aspiration]
    @State private var showingAddSheet = false
    @State private var aspirationPendingDelete: Aspiration?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(aspirations) { aspiration in
                    card(aspiration)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .background(Theme.washedScreen)
        .navigationTitle("Aspirations")
        .toolbar {
            ToolbarItem {
                Button { showingAddSheet = true } label: {
                    Label("Add Aspiration", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AspirationFormView()
        }
        .confirmationDialog(
            "Delete \(aspirationPendingDelete?.title ?? "Aspiration")?",
            isPresented: deleteConfirmationPresented,
            titleVisibility: .visible,
            presenting: aspirationPendingDelete
        ) { aspiration in
            Button("Delete Aspiration", role: .destructive) { delete(aspiration) }
        } message: { _ in
            Text("Its metrics and projects stay in your library. Its intentions go with it.")
        }
        .overlay { emptyState }
    }

    /// Drives the delete dialog off the optional the context-menu action sets,
    /// mirroring the detail screen — the cascade is never one tap away.
    private var deleteConfirmationPresented: Binding<Bool> {
        Binding(
            get: { aspirationPendingDelete != nil },
            set: { presented in if !presented { aspirationPendingDelete = nil } }
        )
    }
}

// MARK: - Pieces

extension AspirationListView {
    private func card(_ aspiration: Aspiration) -> some View {
        NavigationLink(value: aspiration) {
            AspirationCardView(aspiration: aspiration)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                aspirationPendingDelete = aspiration
            } label: {
                Label("Delete Aspiration", systemImage: "trash")
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if aspirations.isEmpty {
            ContentUnavailableView {
                Label("No Aspirations", systemImage: "mountain.2")
            } description: {
                Text("Create an aspiration to see how much you've poured into what matters.")
            } actions: {
                Button("Add Aspiration") { showingAddSheet = true }
            }
        }
    }

    private func delete(_ aspiration: Aspiration) {
        withAnimation {
            modelContext.deleteAspiration(aspiration)
        }
    }
}

// MARK: - The one delete path

extension ModelContext {
    /// The single aspiration delete path, shared by the list's context menu
    /// and the detail screen: the dependents go with no per-row hook, so
    /// their pending daily-question notifications are cancelled explicitly
    /// before the delete (see `deleteAspirationAndDependents` for why the
    /// dependents are deleted explicitly too).
    func deleteAspiration(_ aspiration: Aspiration) {
        NotificationService.cancelQuestions(for: aspiration)
        do {
            try deleteAspirationAndDependents(aspiration)
        } catch {
            StoreLog.error("Aspiration delete failed: \(error)")
        }
    }
}
