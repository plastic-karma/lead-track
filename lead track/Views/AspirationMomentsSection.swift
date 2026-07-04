import SwiftData
import SwiftUI
import UIKit

/// The Moments block of the aspiration detail — the evidence, placed
/// deliberately between the "why" and the Pulse: the reader scrolls past what
/// grew before the Pulse asks whether the effort still serves the why. Shows
/// the three most recent moments with their place and photos, always offers to
/// keep another, and pushes the full timeline once there are more than three.
/// It never begs and never counts.
extension AspirationDetailView {
    var momentsSection: some View {
        Section("Moments") {
            momentsBody
            Button {
                showingKeepMoment = true
            } label: {
                Label("Keep a moment", systemImage: "plus.circle")
            }
        }
    }

    @ViewBuilder
    private var momentsBody: some View {
        if recentMoments.isEmpty {
            Text("Nothing kept yet.")
                .font(.callout)
                .foregroundStyle(.secondary)
        } else {
            ForEach(recentMoments) { moment in
                momentRow(moment)
            }
            if aspiration.moments.count > Self.recentMomentLimit {
                allMomentsLink
            }
        }
    }

    private var allMomentsLink: some View {
        NavigationLink {
            MomentListView(aspiration: aspiration)
        } label: {
            Text("All moments")
                .font(.subheadline)
        }
    }
}

// MARK: - Rows

extension AspirationDetailView {
    /// Newest first — the detail and timeline read most-recent-down, only the
    /// weekly review reads a week as a forward chronicle.
    private var recentMoments: [Moment] {
        Array(
            aspiration.moments
                .sorted { $0.occurredAt > $1.occurredAt }
                .prefix(Self.recentMomentLimit)
        )
    }

    private func momentRow(_ moment: Moment) -> some View {
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

extension AspirationDetailView {
    /// A moment with photos routes through a confirmation (photos are lost with
    /// it); a text-only moment deletes straight away, the swipe already being a
    /// deliberate gesture.
    private func requestDelete(_ moment: Moment) {
        if moment.photos.isEmpty {
            deleteMoment(moment)
        } else {
            momentPendingDelete = moment
        }
    }

    func deleteMoment(_ moment: Moment) {
        withAnimation {
            modelContext.delete(moment)
        }
    }
}

extension AspirationDetailView {
    /// How many moments the detail shows inline before offering the full
    /// timeline. Never surfaced as a count anywhere.
    static var recentMomentLimit: Int {
        3
    }
}

// MARK: - Shared row

/// One moment as it reads on the aspiration's surfaces: the testimony, the day
/// it happened, the place when kept, and a thumbnail strip when photographed.
/// Extracted so the detail and the full timeline render moments identically.
struct MomentRowContent: View {
    let moment: Moment

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(moment.text)
                .font(.subheadline)
                .lineLimit(4)
            meta
            if !moment.photos.isEmpty {
                thumbs
            }
        }
        .padding(.vertical, 2)
    }

    private var meta: some View {
        HStack(spacing: 10) {
            Text(moment.occurredAt.formatted(.dateTime.month(.abbreviated).day().year()))
            if let place = moment.placeLabel {
                Label(place, systemImage: "mappin")
                    .labelStyle(.titleAndIcon)
                    .lineLimit(1)
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private var thumbs: some View {
        HStack(spacing: 6) {
            ForEach(sortedPhotos) { photo in
                thumb(photo.data)
            }
        }
    }

    private var sortedPhotos: [MomentPhoto] {
        moment.photos.sorted { $0.sortIndex < $1.sortIndex }
    }

    @ViewBuilder
    private func thumb(_ data: Data) -> some View {
        if let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }
}
