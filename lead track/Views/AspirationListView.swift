import SwiftData
import SwiftUI

/// The Aspirations tab: a scrolling list of aspiration cards, each a lens over
/// the effort poured into its attached metrics and projects. A peer of the
/// Today dashboard; an app with no aspirations shows a friendly empty state.
struct AspirationListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Aspiration.createdAt) private var aspirations: [Aspiration]
    @State private var showingAddSheet = false
    /// The card lifted by a long-press drag, dimmed in place until the drop.
    @State private var draggingID: String?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(aspirations.inDisplayOrder) { aspiration in
                    card(aspiration)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .aspirationReorderDropSurface(draggingID: $draggingID)
        .background(Theme.washedScreen)
        .navigationTitle("Aspirations")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                appMenu
            }
            ToolbarItem {
                Button { showingAddSheet = true } label: {
                    Label("Add Aspiration", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AspirationFormView()
        }
        .overlay { emptyState }
    }
}

// MARK: - Pieces

extension AspirationListView {
    private var appMenu: some View {
        Menu {
            NavigationLink(value: AllMetricsRoute()) {
                Label("All Metrics", systemImage: "list.bullet")
            }
        } label: {
            Label("More", systemImage: "ellipsis.circle")
        }
    }

    /// One aspiration card: tap navigates, long-press lifts it for reorder —
    /// deliberately nothing else on long-press. Deleting lives on the detail
    /// screen alone, so the cascade is never one hold-and-tap away from the
    /// list and the drag never competes with a context menu.
    private func card(_ aspiration: Aspiration) -> some View {
        NavigationLink(value: aspiration) {
            AspirationCardView(aspiration: aspiration)
        }
        .buttonStyle(.plain)
        .aspirationReorderable(
            id: aspiration.stableIdentity, draggingID: $draggingID, move: move
        )
    }

    /// One hover step of a drag: rewrite the ranks and save, so the order
    /// survives however the drag session ends.
    private func move(_ draggedID: String, over targetID: String) {
        withAnimation(.snappy) {
            AspirationReorder.applyMove(
                all: aspirations,
                visibleIDs: aspirations.inDisplayOrder.map(\.stableIdentity),
                draggedID: draggedID,
                targetID: targetID
            )
            try? modelContext.save()
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
}

// MARK: - The one delete path

extension ModelContext {
    /// The single aspiration delete path, called from the detail screen —
    /// deliberately the only place an aspiration can be deleted: the
    /// dependents go with no per-row hook, so their pending daily-question
    /// notifications are cancelled explicitly after the delete commits (see
    /// `deleteAspirationAndDependents` for why the dependents are deleted
    /// explicitly too).
    func deleteAspiration(_ aspiration: Aspiration) {
        do {
            let questionIDs = try fetch(FetchDescriptor<Intention>())
                .filter { $0.aspiration === aspiration }
                .compactMap(\.stableID)
            try transaction {
                try deleteAspirationAndDependents(aspiration)
            }
            NotificationService.cancelQuestions(stableIDs: questionIDs)
        } catch {
            StoreLog.error("Aspiration delete failed: \(error)")
        }
    }
}
