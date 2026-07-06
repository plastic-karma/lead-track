import SwiftData
import SwiftUI
import UIKit

/// The "Story so far" card of the aspiration detail — the evidence and the
/// effort as one narrative: the most recent kept moments with their place and
/// photos, the quiet doorways to keep another and to the full timeline, and,
/// closing the card, the effort ledger. It never begs and never counts.
extension AspirationDetailView {
    var storyCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            cardHeader("The story so far")
            momentsBlock
            plusRow("Keep a moment") { showingKeepMoment = true }
            allMomentsRow
            cardDivider()
            effortLedger
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.cardShape())
    }

    @ViewBuilder
    private var momentsBlock: some View {
        if recentMoments.isEmpty {
            Text("Nothing kept yet.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.vertical, 11)
            cardDivider()
        } else {
            ForEach(recentMoments) { moment in
                momentRow(moment)
                cardDivider()
            }
        }
    }

    /// The doorway to the full timeline — always open once anything is kept,
    /// and never carrying a count.
    @ViewBuilder
    private var allMomentsRow: some View {
        if !aspiration.moments.isEmpty {
            cardDivider()
            NavigationLink {
                MomentListView(aspiration: aspiration)
            } label: {
                HStack {
                    Text("All moments")
                        .font(.subheadline)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 11)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
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

    /// Tap edits; the swipe of the old list rows becomes a context menu here
    /// (card rows don't swipe), with the same photo-loss confirmation.
    private func momentRow(_ moment: Moment) -> some View {
        Button {
            editingMoment = moment
        } label: {
            MomentRowContent(moment: moment)
                .padding(.vertical, 11)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Edit", systemImage: "pencil") { editingMoment = moment }
            Button("Delete", systemImage: "trash", role: .destructive) {
                requestDelete(moment)
            }
        }
    }
}

// MARK: - Effort ledger

extension AspirationDetailView {
    /// The card's closing figures — recomputed on every render, the
    /// `AspirationRollup` doctrine — with the quiet zero states.
    private var effortLedger: some View {
        ledgerBody(AspirationRollup.compute(for: aspiration))
            .padding(.top, 12)
            .padding(.bottom, 14)
    }

    @ViewBuilder
    private func ledgerBody(_ rollup: AspirationRollup) -> some View {
        if rollup.attachmentCount == 0 {
            Text("Nothing attached yet — add metrics or projects below.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        } else if rollup.hasData {
            AspirationRollupHeader(rollup: rollup)
        } else {
            Text("Nothing logged yet")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Delete

extension AspirationDetailView {
    /// A moment with photos routes through a confirmation (photos are lost with
    /// it); a text-only moment deletes straight away, the menu action already
    /// being a deliberate choice.
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
    /// How many moments the story card shows inline before the timeline takes
    /// over. Never surfaced as a count anywhere.
    static var recentMomentLimit: Int {
        2
    }
}

// MARK: - Shared row

/// One moment as it reads on the aspiration's surfaces: the testimony, then
/// the day and place on one quiet line, and a thumbnail strip when
/// photographed. Extracted so the detail and the full timeline render moments
/// identically.
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
        Text(metaText)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
    }

    private var metaText: String {
        let day = moment.occurredAt.formatted(.dateTime.month(.abbreviated).day().year())
        guard let place = moment.placeLabel else { return day }
        return "\(day) · \(place)"
    }

    private var thumbs: some View {
        HStack(spacing: 7) {
            ForEach(sortedPhotos) { photo in
                thumb(photo.data)
            }
        }
        .padding(.top, 3)
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
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
}
