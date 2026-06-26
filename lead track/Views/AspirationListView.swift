import SwiftData
import SwiftUI

/// The Aspirations tab: a scrolling list of aspiration cards, each a lens over
/// the effort poured into its attached metrics and projects. A peer of the
/// Today dashboard; an app with no aspirations shows a friendly empty state.
struct AspirationListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Aspiration.createdAt) private var aspirations: [Aspiration]
    @State private var showingAddSheet = false

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
        .background(Theme.screenBackground)
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
        .overlay { emptyState }
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
                delete(aspiration)
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
            modelContext.delete(aspiration)
        }
    }
}
