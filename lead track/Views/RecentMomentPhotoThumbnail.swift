import Photos
import SwiftUI
import UIKit

/// One cancellable PhotoKit thumbnail cell. Selection chrome lives here so a
/// grid refresh never starts another full asset request.
struct RecentMomentPhotoThumbnail: View {
    let photo: RecentMomentPhotoLibrary.Photo
    let library: RecentMomentPhotoLibrary
    let selectionNumber: Int?

    @State private var image: UIImage?
    @State private var requestID: PHImageRequestID?

    var body: some View {
        Rectangle()
            .fill(Theme.chipFill)
            .aspectRatio(1, contentMode: .fit)
            .overlay { thumbnail }
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(alignment: .topTrailing) { selectionBadge }
            .onAppear(perform: requestThumbnail)
            .onDisappear(perform: cancelThumbnail)
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            ProgressView()
        }
    }

    @ViewBuilder
    private var selectionBadge: some View {
        if let selectionNumber {
            Text(selectionNumber.formatted())
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(.tint, in: Circle())
                .padding(5)
        }
    }

    private func requestThumbnail() {
        guard image == nil, requestID == nil else { return }
        requestID = library.requestThumbnail(
            for: photo,
            targetSize: CGSize(width: 320, height: 320)
        ) { loaded in
            image = loaded
            requestID = nil
        }
    }

    private func cancelThumbnail() {
        guard let requestID else { return }
        library.cancelThumbnail(requestID)
        self.requestID = nil
    }
}
