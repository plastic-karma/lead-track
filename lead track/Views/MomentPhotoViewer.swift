import Foundation
import SwiftUI
import UIKit

/// One full-screen photo presentation. The route snapshots the moment's
/// ordered photo bytes so paging remains stable even if the presenting row is
/// redrawn while the cover is open.
struct MomentPhotoViewerRoute: Identifiable {
    let id = UUID()
    let photos: [Data]
    let selectedIndex: Int

    init(photos: [Data], selectedIndex: Int) {
        self.photos = photos
        self.selectedIndex = min(max(selectedIndex, 0), max(photos.count - 1, 0))
    }
}

/// An uncropped, edge-to-edge view of a moment's photos. Swiping moves through
/// the rest of the moment without returning to the thumbnail strip.
struct MomentPhotoViewer: View {
    @Environment(\.dismiss) private var dismiss

    let photos: [Data]
    @State private var selection: Int

    init(route: MomentPhotoViewerRoute) {
        photos = route.photos
        _selection = State(initialValue: route.selectedIndex)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            photoPages
        }
        .overlay(alignment: .top) { controls }
        .statusBarHidden()
        .accessibilityIdentifier("MomentPhotoViewer")
    }

    @ViewBuilder
    private var photoPages: some View {
        if photos.isEmpty {
            unavailablePhoto
        } else {
            TabView(selection: $selection) {
                ForEach(photos.indices, id: \.self) { index in
                    photo(at: index)
                        .tag(index)
                }
            }
            .tabViewStyle(
                .page(indexDisplayMode: photos.count > 1 ? .automatic : .never)
            )
        }
    }

    @ViewBuilder
    private func photo(at index: Int) -> some View {
        if let image = UIImage(data: photos[index]) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.vertical, 56)
                .accessibilityLabel(photoLabel(at: index))
        } else {
            unavailablePhoto
        }
    }

    private var unavailablePhoto: some View {
        ContentUnavailableView(
            "Photo unavailable",
            systemImage: "photo.badge.exclamationmark"
        )
        .foregroundStyle(.white)
    }

    private var controls: some View {
        HStack {
            if photos.count > 1 {
                Text("\(selection + 1) of \(photos.count)")
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .padding(.horizontal, 13)
                    .frame(height: 44)
                    .background(.black.opacity(0.55), in: Capsule())
            }
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.headline.weight(.semibold))
                    .frame(width: 44, height: 44)
                    .background(.black.opacity(0.55), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close photo")
            .accessibilityIdentifier("CloseMomentPhotoViewer")
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private func photoLabel(at index: Int) -> String {
        photos.count == 1
            ? "Moment photo"
            : "Moment photo \(index + 1) of \(photos.count)"
    }
}
