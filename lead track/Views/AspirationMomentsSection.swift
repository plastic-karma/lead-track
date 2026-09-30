import SwiftData
import SwiftUI
import UIKit

/// The "Story so far" card of the aspiration detail — the evidence and the
/// effort as one narrative: the most recent kept moments with their place and
/// photos, the quiet doorways to keep another and to the full timeline, and,
/// closing the card, the effort ledger. It never begs and never counts.
struct AspirationStoryCard: View {
    @Environment(\.modelContext) private var modelContext
    let aspiration: Aspiration
    @State private var isExpanded = true
    @State private var showingKeepMoment = false
    @State private var editingMoment: Moment?
    @State private var photoViewerRoute: MomentPhotoViewerRoute?
    @State private var momentPendingDelete: Moment?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            AspirationCardHeader(title: "The story so far", isExpanded: $isExpanded)
            if isExpanded {
                AspirationRecentMoments(
                    aspiration: aspiration, editingMoment: $editingMoment,
                    photoViewerRoute: $photoViewerRoute, onDelete: requestDelete
                )
                if !aspiration.isArchived {
                    AspirationPlusRow(title: "Keep a moment", tint: aspiration.displayColor) {
                        showingKeepMoment = true
                    }
                }
                AspirationStoryDoorways(aspiration: aspiration)
                Divider()
                AspirationEffortLedger(aspiration: aspiration)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, isExpanded ? 0 : 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { Theme.cardShape() }
        .sheet(isPresented: $showingKeepMoment) {
            MomentFormView(aspiration: aspiration)
        }
        .sheet(item: $editingMoment) { moment in
            MomentFormView(aspiration: aspiration, moment: moment)
        }
        .fullScreenCover(item: $photoViewerRoute) { route in
            MomentPhotoViewer(route: route)
        }
        .confirmationDialog(
            "Delete this moment?",
            isPresented: momentDeletePresented,
            presenting: momentPendingDelete
        ) { moment in
            Button("Delete Moment", role: .destructive) { deleteMoment(moment) }
        } message: { _ in
            Text("Its photos are deleted with it. This can't be undone.")
        }
    }
}

private struct AspirationRecentMoments: View {
    let aspiration: Aspiration
    @Binding var editingMoment: Moment?
    @Binding var photoViewerRoute: MomentPhotoViewerRoute?
    let onDelete: (Moment) -> Void

    var body: some View {
        if recentMoments.isEmpty {
            Text("Nothing kept yet.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.vertical, 11)
            Divider()
        } else {
            ForEach(recentMoments) { moment in
                MomentRowContent(
                    moment: moment,
                    onEdit: { editingMoment = moment },
                    onPhotoTap: { photoViewerRoute = $0 }
                )
                .padding(.vertical, 11)
                .contentShape(Rectangle())
                .contextMenu {
                    Button("Edit", systemImage: "pencil") { editingMoment = moment }
                    Button("Delete", systemImage: "trash", role: .destructive) {
                        onDelete(moment)
                    }
                }
                Divider()
            }
        }
    }

    private var recentMoments: [Moment] {
        Array(aspiration.moments.sorted { $0.occurredAt > $1.occurredAt }.prefix(2))
    }
}

private struct AspirationStoryDoorways: View {
    let aspiration: Aspiration

    var body: some View {
        allMomentsRow
        periodHistoryRow
    }

    @ViewBuilder
    private var allMomentsRow: some View {
        if !aspiration.moments.isEmpty {
            Divider()
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

    private var periodHistoryRow: some View {
        NavigationLink {
            let end = Date.now
            let start = Calendar.current.date(
                byAdding: .day, value: -AspirationRollup.recentWindowDays, to: end
            ) ?? end
            RetrospectiveView(
                period: DateInterval(start: start, end: end), aspiration: aspiration
            )
        } label: {
            HStack {
                Text("Explore a period")
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

// MARK: - Effort ledger

private struct AspirationEffortLedger: View {
    let aspiration: Aspiration

    var body: some View {
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
            AspirationRollupHeader(
                lifetimeSummary: rollup.lifetimeSummary, recentParts: rollup.recentParts
            )
        } else {
            Text("Nothing logged yet")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Delete

extension AspirationStoryCard {
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

    private func deleteMoment(_ moment: Moment) {
        withAnimation {
            do {
                try modelContext.deleteMomentAndPhotos(moment)
            } catch {
                StoreLog.error("Moment delete failed: \(error)")
            }
        }
    }
}

extension AspirationStoryCard {
    private var momentDeletePresented: Binding<Bool> {
        Binding(
            get: { momentPendingDelete != nil },
            set: { presented in if !presented { momentPendingDelete = nil } }
        )
    }
}

// MARK: - Shared row

/// One moment as it reads on the aspiration's surfaces: the testimony, then
/// the day, the place, and the principle it lives on one quiet line, and a
/// thumbnail strip when photographed. Extracted so the detail and the full
/// timeline render moments identically.
struct MomentRowContent: View {
    let moment: Moment
    let onEdit: () -> Void
    let onPhotoTap: (MomentPhotoViewerRoute) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            MomentRowTestimony(moment: moment, onEdit: onEdit)
            if !moment.photos.isEmpty {
                MomentRowPhotos(moment: moment, onPhotoTap: onPhotoTap)
            }
        }
        .padding(.vertical, 2)
    }
}

private struct MomentRowTestimony: View {
    let moment: Moment
    let onEdit: () -> Void

    var body: some View {
        Button(action: onEdit) {
            VStack(alignment: .leading, spacing: 6) {
                Text(moment.text)
                    .font(.subheadline)
                    .lineLimit(4)
                Text(metaText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var metaText: String {
        let day = moment.occurredAt.formatted(.dateTime.month(.abbreviated).day().year())
        return [day, moment.placeLabel, livesTag]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    /// The principle this testimony lives, quoted — provenance in the creed.
    private var livesTag: String? {
        moment.principle.map { "lives “\($0.text)”" }
    }
}

private struct MomentRowPhotos: View {
    private struct Source: Equatable {
        let id: PersistentIdentifier
        let data: Data
    }

    private struct Thumbnail: Identifiable {
        let id: PersistentIdentifier
        let index: Int
        let image: UIImage
    }

    private struct PreparedPhotos {
        let sources: [Source]
        let thumbnails: [Thumbnail]
    }

    let moment: Moment
    let onPhotoTap: (MomentPhotoViewerRoute) -> Void
    @State private var prepared = PreparedPhotos(sources: [], thumbnails: [])

    var body: some View {
        let sources = moment.photos.sorted { $0.sortIndex < $1.sortIndex }
            .map { Source(id: $0.id, data: $0.data) }
        HStack(spacing: 7) {
            if prepared.sources == sources {
                ForEach(prepared.thumbnails) { thumbnail in
                    Button {
                        onPhotoTap(
                            MomentPhotoViewerRoute(
                                photos: sources.map(\.data),
                                selectedIndex: thumbnail.index
                            )
                        )
                    } label: {
                        Image(uiImage: thumbnail.image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 48, height: 48)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("View photo \(thumbnail.index + 1) of \(sources.count)")
                    .accessibilityHint("Opens the photo full screen")
                }
            }
        }
        .padding(.top, 3)
        .task(id: sources) {
            prepared = PreparedPhotos(
                sources: sources,
                thumbnails: sources.enumerated().compactMap { index, source in
                    guard let image = UIImage(data: source.data) else { return nil }
                    return Thumbnail(id: source.id, index: index, image: image)
                }
            )
        }
    }
}
