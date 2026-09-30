import SwiftUI

/// Full saved testimony, without the timeline row's edit action or truncation.
struct RetrospectiveMomentRow: View {
    let moment: Moment
    @State private var photoRoute: MomentPhotoViewerRoute?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(moment.text).font(.subheadline).textSelection(.enabled)
            Text(moment.occurredAt, format: Date.FormatStyle(date: .abbreviated, time: .omitted))
                .font(.caption).foregroundStyle(.secondary)
            RetrospectiveMomentProvenance(
                aspirationTitle: moment.aspiration?.title,
                principleText: moment.principle?.text,
                projectName: moment.project?.name,
                placeLabel: moment.placeLabel
            )
            if !moment.photos.isEmpty {
                RetrospectiveMomentPhotos(moment: moment, route: $photoRoute)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
        .fullScreenCover(item: $photoRoute) { MomentPhotoViewer(route: $0) }
    }
}

private struct RetrospectiveMomentProvenance: View {
    let aspirationTitle: String?
    let principleText: String?
    let projectName: String?
    let placeLabel: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            if let aspirationTitle { Text(aspirationTitle) }
            if let principleText { Text("lives “\(principleText)”") }
            if let projectName { Text(projectName) }
            if let placeLabel { Text(placeLabel) }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}

private struct RetrospectiveMomentPhotos: View {
    let moment: Moment
    @Binding var route: MomentPhotoViewerRoute?

    var body: some View {
        let photos = moment.photos.sorted { $0.sortIndex < $1.sortIndex }
        ScrollView(.horizontal) {
            HStack(spacing: 7) {
                ForEach(photos.enumerated(), id: \.element.id) { index, photo in
                    Button {
                        route = MomentPhotoViewerRoute(photos: photos.map(\.data), selectedIndex: index)
                    } label: {
                        MomentPhotoThumbnail(data: photo.data, size: 64)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("View photo \(index + 1) of \(photos.count)")
                    .accessibilityHint("Opens the photo full screen")
                }
            }
        }
        .scrollIndicators(.hidden)
    }
}
