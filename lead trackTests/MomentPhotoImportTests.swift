#if canImport(ImageIO) && canImport(UIKit)
import Foundation
import Testing
import UIKit
@testable import lead_track

struct MomentPhotoImportTests {
    @Test
    func invalidBytesAreRejected() {
        #expect(MomentPhotoImport.downscaledJPEG(from: Data("not an image".utf8)) == nil)
    }

    @Test
    func largeImageIsJPEGWithBoundedLongestEdge() throws {
        let raw = try #require(imageData(width: 4096, height: 1024))

        let imported = try #require(MomentPhotoImport.downscaledJPEG(from: raw))
        let image = try #require(UIImage(data: imported))
        let width = Int(image.size.width * image.scale)
        let height = Int(image.size.height * image.scale)

        #expect(imported.starts(with: [0xFF, 0xD8]))
        #expect(max(width, height) <= MomentPhotoImport.maxPixelSize)
        #expect(abs(Double(width) / Double(height) - 4) < 0.02)
    }

    @Test
    func exifOrientationIsBakedIntoStoredPixels() throws {
        let raw = try #require(orientedJPEG())

        let imported = try #require(MomentPhotoImport.downscaledJPEG(from: raw))
        let image = try #require(UIImage(data: imported))

        #expect(image.imageOrientation == .up)
        #expect(image.size.height > image.size.width)
    }

    private func imageData(width: Int, height: Int) -> Data? {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(
            size: CGSize(width: width, height: height),
            format: format
        ).image { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
        return image.pngData()
    }

    private func orientedJPEG() -> Data? {
        guard let data = imageData(width: 80, height: 40),
              let image = UIImage(data: data),
              let cgImage = image.cgImage
        else { return nil }
        return UIImage(
            cgImage: cgImage,
            scale: 1,
            orientation: .right
        ).jpegData(compressionQuality: 1)
    }
}
#endif
