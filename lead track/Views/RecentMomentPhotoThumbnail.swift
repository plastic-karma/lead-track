import Photos
import SwiftUI
import UIKit

/// Selection changes do not invalidate the independent PhotoKit request host.
struct RecentMomentPhotoThumbnail: View {
    let photo: RecentMomentPhotoLibrary.Photo
    let library: RecentMomentPhotoLibrary
    let selectionNumber: Int?

    var body: some View {
        Rectangle()
            .fill(Theme.chipFill)
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                RecentMomentThumbnailImage(photo: photo, library: library)
                    .id(photo.id)
            }
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(alignment: .topTrailing) {
                if let selectionNumber {
                    Text(selectionNumber.formatted())
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 24, height: 24)
                        .background(.tint, in: Circle())
                        .padding(5)
                }
            }
    }
}

private struct RecentMomentThumbnailImage: View {
    let photo: RecentMomentPhotoLibrary.Photo
    let library: RecentMomentPhotoLibrary
    @State private var image: UIImage?
    @State private var requestID: PHImageRequestID?
    @State private var generation = 0

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                ProgressView()
            }
        }
        .onAppear(perform: requestThumbnail)
        .onDisappear(perform: cancelThumbnail)
    }

    private func requestThumbnail() {
        guard image == nil, requestID == nil else { return }
        generation += 1
        let requestedGeneration = generation
        requestID = library.requestThumbnail(for: photo, targetSize: CGSize(width: 320, height: 320)) { loaded in
            guard generation == requestedGeneration else { return }
            image = loaded
            requestID = nil
        }
    }

    private func cancelThumbnail() {
        generation += 1
        if let requestID { library.cancelThumbnail(requestID) }
        requestID = nil
    }
}
