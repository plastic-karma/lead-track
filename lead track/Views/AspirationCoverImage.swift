import SwiftUI
import UIKit

// How an aspiration's stored cover bytes become pixels, gathered out of the
// row and banner view files so the decode policy lives in one place.

extension Aspiration {
    /// The cached full-resolution cover for the detail banner.
    @MainActor
    var coverImage: Image? {
        guard let data = imageData, let uiImage = AspirationCoverImages.image(from: data) else {
            return nil
        }
        return Image(uiImage: uiImage)
    }

    /// A downsampled cover thumbnail, decoded at most once per photo: the
    /// result is cached keyed by the photo bytes themselves, so replacing a
    /// cover can never serve the stale image, and re-created list rows render
    /// from the cache instead of decoding in body.
    @MainActor
    func coverThumbnail(fitting side: CGFloat) -> UIImage? {
        guard let data = imageData else { return nil }
        return AspirationCoverThumbnails.thumbnail(from: data, fitting: side)
    }
}

/// Full-resolution covers reuse UIKit image objects across the editor and banner.
/// Exact bytes form the key, so replacing a cover cannot return stale pixels.
@MainActor
enum AspirationCoverImages {
    private static let cache: NSCache<NSData, UIImage> = {
        let cache = NSCache<NSData, UIImage>()
        cache.countLimit = 4
        cache.totalCostLimit = 64 * 1024 * 1024
        return cache
    }()

    static func image(from data: Data) -> UIImage? {
        let key = data as NSData
        if let image = cache.object(forKey: key) { return image }
        guard let image = UIImage(data: data) else { return nil }
        let decodedBytes = image.cgImage.map { $0.bytesPerRow * $0.height }
            ?? Int(image.size.width * image.scale) * Int(image.size.height * image.scale) * 4
        cache.setObject(image, forKey: key, cost: data.count + decodedBytes)
        return image
    }
}

/// The decode-once store behind `coverThumbnail(fitting:)`. `NSCache` frees
/// entries under memory pressure; the cost of that is one re-decode.
@MainActor
private enum AspirationCoverThumbnails {
    /// Thumbnails keyed by the exact photo bytes (`NSCache` retains keys
    /// without copying, and the model already holds the data). One thumbnail
    /// per photo — every small surface today asks for the row size.
    private static let cache = NSCache<NSData, UIImage>()

    /// Pixels per point on the densest display the app ships to, so one
    /// decode stays sharp everywhere without consulting a screen.
    private static let maxDisplayScale: CGFloat = 3

    static func thumbnail(from data: Data, fitting side: CGFloat) -> UIImage? {
        let key = data as NSData
        if let cached = cache.object(forKey: key) {
            return cached
        }
        guard let thumbnail = decode(data, shortEdge: side * maxDisplayScale) else {
            return nil
        }
        cache.setObject(thumbnail, forKey: key)
        return thumbnail
    }

    /// An aspect-preserving downsample whose short edge lands on `shortEdge`
    /// pixels, so a `scaledToFill` square crop loses no sharpness. Images
    /// already small enough decode as they are.
    private static func decode(_ data: Data, shortEdge: CGFloat) -> UIImage? {
        guard let image = UIImage(data: data) else { return nil }
        let smallestSide = min(image.size.width, image.size.height)
        guard smallestSide > shortEdge else { return image }
        let ratio = shortEdge / smallestSide
        let target = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)
        return image.preparingThumbnail(of: target) ?? image
    }
}
