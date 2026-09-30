import Foundation
import SwiftUI
import UIKit

/// One full-screen photo presentation. Each occurrence gets its own identity
/// when the route snapshots the ordered bytes, including duplicate images.
struct MomentPhotoViewerRoute: Identifiable {
    let id = UUID()
    let photos: [MomentPhotoSnapshot]
    let selectedPhotoID: UUID?

    init(photos: [Data], selectedIndex: Int) {
        let snapshots = photos.map { MomentPhotoSnapshot(data: $0) }
        self.photos = snapshots
        let index = min(max(selectedIndex, 0), max(snapshots.count - 1, 0))
        selectedPhotoID = snapshots.isEmpty ? nil : snapshots[index].id
    }
}

struct MomentPhotoSnapshot: Identifiable {
    let id = UUID()
    let data: Data
}

/// An uncropped, edge-to-edge view of a moment's photos. The cover owns an
/// immutable snapshot, so edits to the presenting moment cannot shift selection.
struct MomentPhotoViewer: View {
    let photos: [MomentPhotoSnapshot]
    @State private var selection: UUID?

    init(route: MomentPhotoViewerRoute) {
        photos = route.photos
        _selection = State(initialValue: route.selectedPhotoID)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if photos.isEmpty {
                MomentUnavailablePhoto()
            } else {
                TabView(selection: $selection) {
                    ForEach(photos.enumerated(), id: \.element.id) { index, photo in
                        Tab(value: Optional(photo.id)) {
                            MomentPhotoPage(data: photo.data, number: index + 1, count: photos.count)
                        }
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: photos.count > 1 ? .automatic : .never))
            }
        }
        .overlay(alignment: .top) {
            MomentPhotoControls(
                number: photos.firstIndex { $0.id == selection }.map { $0 + 1 } ?? 1,
                count: photos.count
            )
        }
        .statusBarHidden()
        .accessibilityIdentifier("MomentPhotoViewer")
    }
}

private struct MomentPhotoPage: View {
    let data: Data
    let number: Int
    let count: Int
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.vertical, 56)
                    .accessibilityLabel(count == 1 ? "Moment photo" : "Moment photo \(number) of \(count)")
            } else {
                MomentUnavailablePhoto()
            }
        }
        .task(id: data) { image = UIImage(data: data) }
    }
}

private struct MomentUnavailablePhoto: View {
    var body: some View {
        ContentUnavailableView("Photo unavailable", systemImage: "photo.badge.exclamationmark")
            .foregroundStyle(.white)
    }
}

private struct MomentPhotoControls: View {
    @Environment(\.dismiss) private var dismiss
    let number: Int
    let count: Int

    var body: some View {
        HStack {
            if count > 1 {
                Text("\(number) of \(count)")
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
}

/// Review thumbnails decode once per photo change and preserve the unavailable placeholder.
struct MomentPhotoThumbnail: View {
    let data: Data
    let size: CGFloat
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Image(systemName: "photo")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .task(id: data) { image = UIImage(data: data) }
    }
}
