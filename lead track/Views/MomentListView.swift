import SwiftData
import SwiftUI

/// The full moments timeline for one aspiration — every kept moment, newest
/// first, places and photos inline. Reached from the detail's "All moments"
/// link once more than a few exist. Tapping a row edits it, swiping deletes it
/// (with a confirmation when photos would be lost), exactly as on the detail.
/// No count is ever shown, here or in the link that leads here.
struct MomentListView: View {
    @Environment(\.modelContext) private var modelContext
    let aspiration: Aspiration
    @State private var editingMoment: Moment?
    @State private var momentPendingDelete: Moment?

    var body: some View {
        List {
            ForEach(sortedMoments) { moment in
                row(moment)
            }
        }
        .navigationTitle("Moments")
        .navigationBarTitleDisplayMode(.inline)
        .overlay { emptyState }
        .sheet(item: $editingMoment) { moment in
            MomentFormView(aspiration: aspiration, moment: moment)
        }
        .confirmationDialog(
            "Delete this moment?",
            isPresented: deletePresented,
            presenting: momentPendingDelete
        ) { moment in
            Button("Delete Moment", role: .destructive) { delete(moment) }
        } message: { _ in
            Text("Its photos are deleted with it. This can't be undone.")
        }
    }
}

// MARK: - Rows & state

extension MomentListView {
    private var sortedMoments: [Moment] {
        aspiration.moments.sorted { $0.occurredAt > $1.occurredAt }
    }

    @ViewBuilder
    private var emptyState: some View {
        if sortedMoments.isEmpty {
            ContentUnavailableView("Nothing kept yet", systemImage: "sparkles")
        }
    }

    private func row(_ moment: Moment) -> some View {
        Button {
            editingMoment = moment
        } label: {
            MomentRowContent(moment: moment)
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing) {
            Button("Delete", role: .destructive) {
                requestDelete(moment)
            }
        }
    }
}

// MARK: - Delete

extension MomentListView {
    private var deletePresented: Binding<Bool> {
        Binding(
            get: { momentPendingDelete != nil },
            set: { presented in if !presented { momentPendingDelete = nil } }
        )
    }

    private func requestDelete(_ moment: Moment) {
        if moment.photos.isEmpty {
            delete(moment)
        } else {
            momentPendingDelete = moment
        }
    }

    private func delete(_ moment: Moment) {
        withAnimation {
            modelContext.delete(moment)
        }
    }
}
