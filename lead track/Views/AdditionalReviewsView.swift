import SwiftUI

/// Lists every additional review. The fixed Weekly Review is intentionally
/// absent: it keeps its existing bell settings and Week-tab behavior.
struct AdditionalReviewsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AdditionalReviewStore.key) private var encodedReviews = Data()
    @State private var showingAddForm = false
    @State private var editingReview: AdditionalReview?

    private var reviews: [AdditionalReview] {
        AdditionalReviewStore.decode(encodedReviews)
    }

    var body: some View {
        NavigationStack {
            content
        }
        .sheet(isPresented: $showingAddForm) {
            AdditionalReviewFormView(save: save)
        }
        .sheet(item: $editingReview) { review in
            AdditionalReviewFormView(review: review, save: save)
        }
        .onAppear { loadMigratedReviews() }
    }

    private var content: some View {
        let decoded = reviews
        return Group {
            if decoded.isEmpty {
                emptyState
            } else {
                reviewList(decoded)
            }
        }
        .navigationTitle("More Reviews")
        .toolbar { toolbarItems }
    }

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Done") { dismiss() }
        }
        ToolbarItem(placement: .primaryAction) {
            Button { showingAddForm = true } label: {
                Label("Add Review", systemImage: "plus")
            }
        }
    }

    private func reviewList(_ reviews: [AdditionalReview]) -> some View {
        List {
            ForEach(reviews) { review in
                reviewLink(review)
            }
            .onDelete(perform: remove)
        }
    }

    private func reviewLink(_ review: AdditionalReview) -> some View {
        NavigationLink {
            AdditionalReviewDetailView(reviewID: review.id)
        } label: {
            AdditionalReviewListRow(review: review)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                remove(review)
            } label: {
                Label("Delete", systemImage: "trash")
            }
            Button {
                editingReview = review
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(.accentColor)
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Additional Reviews", systemImage: "calendar.badge.plus")
        } description: {
            Text("Add monthly, quarterly, yearly, or custom review periods.")
        } actions: {
            Button("Add Review") { showingAddForm = true }
                .buttonStyle(.borderedProminent)
        }
    }

    private func save(_ review: AdditionalReview) {
        let updated = AdditionalReviewStore.upserting(review, in: reviews)
        encodedReviews = AdditionalReviewStore.encode(updated)
        NotificationService.rescheduleAdditionalReviews()
    }

    private func remove(_ review: AdditionalReview) {
        encodedReviews = AdditionalReviewStore.encode(
            AdditionalReviewStore.removing(id: review.id, from: reviews)
        )
        NotificationService.rescheduleAdditionalReviews()
    }

    private func loadMigratedReviews() {
        guard encodedReviews.isEmpty else { return }
        encodedReviews = AdditionalReviewStore.encode(AdditionalReviewStore.reviews())
    }

    private func remove(at offsets: IndexSet) {
        var updated = reviews
        updated.remove(atOffsets: offsets)
        encodedReviews = AdditionalReviewStore.encode(updated)
        NotificationService.rescheduleAdditionalReviews()
    }
}

private struct AdditionalReviewListRow: View {
    let review: AdditionalReview
    @Environment(\.locale) private var locale
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(review.name)
                .font(.headline)
            Text(cadenceDescription(review))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(nextDescription(review))
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }

    private func cadenceDescription(_ review: AdditionalReview) -> String {
        switch review.cycle {
        case .monthly: "Monthly"
        case .quarterly: "Quarterly"
        case .yearly: "Yearly"
        case .custom:
            customCadenceDescription(review)
        }
    }

    private func customCadenceDescription(_ review: AdditionalReview) -> String {
        let unit = review.customUnit == .days
            ? (review.boundedInterval == 1 ? "day" : "days")
            : (review.boundedInterval == 1 ? "month" : "months")
        return "Every \(review.boundedInterval.formatted(.number.locale(locale))) \(unit)"
    }

    private func nextDescription(_ review: AdditionalReview) -> String {
        let date = AdditionalReviewSchedule.nextReviewDate(for: review)
        return "Next: \(date.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened).locale(locale)))"
    }
}
