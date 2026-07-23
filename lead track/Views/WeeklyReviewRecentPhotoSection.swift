import Foundation
import SwiftUI

// MARK: - Week section

extension WeeklyReviewView {
    /// A quiet capture doorway for the live trailing-seven-day review. The
    /// picker is a leaf so its authorization, thumbnail, and selection changes
    /// never rebuild the review's full aggregation.
    @ViewBuilder
    func recentPhotosSection(_ review: WeeklyReview) -> some View {
        if review.weeksBack == 0, !aspirations.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                sectionBreak("Moments")
                WeeklyRecentPhotosSection(
                    window: RecentPhotoWindow(start: review.start, end: review.end)
                )
            }
            .padding(.horizontal)
        }
    }
}

private struct WeeklyRecentPhotosSection: View {
    let window: RecentPhotoWindow

    @State private var showingPicker = false
    @State private var queuedDraft: WeeklyMomentPhotoDraft?
    @State private var composerDraft: WeeklyMomentPhotoDraft?

    var body: some View {
        captureCard
            .sheet(isPresented: $showingPicker, onDismiss: presentQueuedDraft) {
                RecentMomentPhotoPicker(window: window, prepare: prepare)
            }
            .sheet(item: $composerDraft) { draft in
                MomentFormView(
                    seed: MomentFormSeed(
                        photos: draft.photos,
                        occurredAt: draft.occurredAt,
                        importFailureCount: draft.failureCount
                    )
                )
            }
    }

    private var captureCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Keep photos from the last 7 days", systemImage: "photo.on.rectangle.angled")
                .font(.subheadline.weight(.medium))
            Text("Choose up to four photos, then add the words and aspiration that make them a moment.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                showingPicker = true
            } label: {
                ActionChip(voice: .opening(.accentColor)) {
                    Label("Choose photos", systemImage: "photo.stack")
                }
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.cardShape())
    }

    private func prepare(_ draft: WeeklyMomentPhotoDraft) {
        queuedDraft = draft
        showingPicker = false
    }

    private func presentQueuedDraft() {
        guard let queuedDraft else { return }
        composerDraft = queuedDraft
        self.queuedDraft = nil
    }
}

struct WeeklyMomentPhotoDraft: Identifiable {
    let id = UUID()
    let photos: [Data]
    let occurredAt: Date
    let failureCount: Int
}
