import SwiftUI
import UIKit

/// Full saved testimony, without the timeline row's edit action or truncation.
/// Photos use the same full-screen route as the existing Moment timeline.
struct RetrospectiveMomentRow: View {
    let moment: Moment
    @State private var photoRoute: MomentPhotoViewerRoute?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(moment.text)
                .font(.subheadline)
                .textSelection(.enabled)
            Text(moment.occurredAt.formatted(date: .abbreviated, time: .omitted))
                .font(.caption)
                .foregroundStyle(.secondary)
            provenance
            if !moment.photos.isEmpty { photos }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
        .fullScreenCover(item: $photoRoute) { MomentPhotoViewer(route: $0) }
    }

    private var provenance: some View {
        VStack(alignment: .leading, spacing: 3) {
            if let aspiration = moment.aspiration { Text(aspiration.title) }
            if let principle = moment.principle { Text("lives “\(principle.text)”") }
            if let project = moment.project { Text(project.name) }
            if let place = moment.placeLabel { Text(place) }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private var photos: some View {
        let photos = moment.photos.sorted { $0.sortIndex < $1.sortIndex }
        return ScrollView(.horizontal) {
            HStack(spacing: 7) {
                ForEach(photos.indices, id: \.self) { index in
                    Button {
                        photoRoute = MomentPhotoViewerRoute(photos: photos.map(\.data), selectedIndex: index)
                    } label: {
                        thumbnail(photos[index])
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("View photo \(index + 1) of \(photos.count)")
                    .accessibilityHint("Opens the photo full screen")
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    private func thumbnail(_ photo: MomentPhoto) -> some View {
        Group {
            if let image = UIImage(data: photo.data) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Image(systemName: "photo").frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(width: 64, height: 64)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
