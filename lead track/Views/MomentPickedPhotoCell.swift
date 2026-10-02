import SwiftUI
import UIKit

/// Identity belongs to the imported occurrence, never its bytes or array slot.
struct PickedPhoto: Identifiable {
    let id = UUID()
    let data: Data
}

struct MomentPickedPhotoCell: View {
    let photo: PickedPhoto
    let number: Int
    let count: Int
    let onRemove: (PickedPhoto) -> Void
    let onView: (PickedPhoto) -> Void
    @State private var image: UIImage?

    var body: some View {
        VStack(spacing: 8) {
            Button { onView(photo) } label: {
                MomentPickedPhotoImage(image: image)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("View photo \(number) of \(count)")
            .accessibilityHint("Opens the photo full screen")
            Button { onRemove(photo) } label: {
                Label("Remove", systemImage: "trash")
                    .font(.caption)
                    .frame(width: 88)
                    .frame(minHeight: 44)
                    .background(Theme.chipFill, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove photo \(number) of \(count)")
            .accessibilityHint("Removes this photo from the moment")
        }
        .task(id: photo.data) { image = UIImage(data: photo.data) }
    }
}

private struct MomentPickedPhotoImage: View {
    let image: UIImage?

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Image(systemName: "photo")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.chipFill)
            }
        }
        .frame(width: 88, height: 88)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Theme.photoOutline, lineWidth: 1)
        }
    }
}
