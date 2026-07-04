import ImageIO
import UIKit
import UniformTypeIdentifiers

/// Downscales a moment photo on import. Unlike the one-off aspiration cover,
/// moment photos accrue for a lifetime, so each is shrunk to a longest-edge
/// ceiling and re-encoded as JPEG before its bytes ever reach `MomentPhoto`.
/// ImageIO downsamples during decode, so a large original never fully inflates
/// in memory. iOS-only (UIKit/ImageIO); never enters `Shared/`.
enum MomentPhotoImport {
    /// Longest edge in pixels after downscaling — enough for a full-screen
    /// Retina view, far below an original camera frame.
    static let maxPixelSize = 2048
    static let jpegQuality: CGFloat = 0.8

    /// Downscaled JPEG bytes, or nil when the data isn't a decodable image.
    /// EXIF orientation is baked in, so the stored bytes render upright with
    /// no further transform.
    static func downscaledJPEG(from data: Data) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(
            source, 0, options as CFDictionary
        ) else { return nil }
        return UIImage(cgImage: cgImage).jpegData(compressionQuality: jpegQuality)
    }
}
