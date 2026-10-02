import SwiftData
import SwiftUI

/// The Aspirations tab: a scrolling list of aspiration cards, each a lens over
/// the effort poured into its attached metrics and projects. A peer of the
/// Today dashboard; an app with no aspirations shows a friendly empty state.
struct AspirationListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \Aspiration.createdAt) private var aspirations: [Aspiration]
    @State private var showingAddSheet = false
    /// The card lifted by a long-press drag, dimmed in place until the drop.
    @State private var draggingID: String?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(aspirations.unarchived.inDisplayOrder) { aspiration in
                    AspirationListCard(
                        aspiration: aspiration, draggingID: $draggingID, move: move
                    )
                }
            }
            .frame(maxWidth: 680)
            .frame(maxWidth: .infinity)
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .aspirationReorderDropSurface(draggingID: $draggingID)
        .background(Theme.washedScreen)
        .navigationTitle("Aspirations")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                AspirationLibraryMenu()
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
        .overlay {
            if aspirations.unarchived.isEmpty {
                AspirationListEmptyState(showingAddSheet: $showingAddSheet)
            }
        }
    }
}

// MARK: - Pieces

extension AspirationListView {
    /// One hover step of a drag: rewrite the ranks and save, so the order
    /// survives however the drag session ends.
    private func move(_ draggedID: String, over targetID: String) {
        withAnimation(reduceMotion ? nil : .snappy) {
            AspirationReorder.applyMove(
                all: aspirations,
                visibleIDs: aspirations.unarchived.inDisplayOrder.map(\.stableIdentity),
                draggedID: draggedID,
                targetID: targetID
            )
            try? modelContext.save()
        }
    }
}

// MARK: - The one delete path

extension ModelContext {
    /// The single aspiration delete path, called from the detail screen —
    /// deliberately the only place an aspiration can be deleted: the
    /// dependents go with no per-row hook, so their pending daily-question
    /// notifications are cancelled explicitly before the delete (see
    /// `deleteAspirationAndDependents` for why the dependents are deleted
    /// explicitly too).
    func deleteAspiration(_ aspiration: Aspiration) {
        NotificationService.cancelQuestions(for: aspiration)
        do {
            try deleteAspirationAndDependents(aspiration)
        } catch {
            StoreLog.error("Aspiration delete failed: \(error)")
        }
    }
}

private struct AspirationLibraryMenu: View {
    var body: some View {
        Menu {
            NavigationLink(value: AllMetricsRoute()) {
                Label("All Metrics", systemImage: "list.bullet")
            }
            NavigationLink {
                SetAsideAspirationsView()
            } label: {
                Label("Set-aside aspirations", systemImage: "archivebox")
            }
        } label: {
            Label("More", systemImage: "ellipsis.circle")
        }
    }
}

private struct AspirationListCard: View {
    let aspiration: Aspiration
    @Binding var draggingID: String?
    let move: (_ draggedID: String, _ targetID: String) -> Void

    var body: some View {
        NavigationLink(value: aspiration) {
            AspirationCardView(aspiration: aspiration)
        }
        .buttonStyle(.plain)
        .aspirationReorderable(
            id: aspiration.stableIdentity, draggingID: $draggingID, move: move
        )
    }
}

private struct AspirationListEmptyState: View {
    @Binding var showingAddSheet: Bool

    var body: some View {
        ContentUnavailableView {
            Label("No Aspirations", systemImage: "mountain.2")
        } description: {
            Text("Create an aspiration to see how much you've poured into what matters.")
        } actions: {
            Button("Add Aspiration") { showingAddSheet = true }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
    }
}
