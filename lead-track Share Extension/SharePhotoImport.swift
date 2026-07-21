import Foundation
import UniformTypeIdentifiers

/// Loads the image providers explicitly handed to the Share Extension and
/// shrinks them before any bytes enter the shared SwiftData store. File-backed
/// representations are preferred so a full camera original is never copied
/// into memory merely to downsample it.
enum SharePhotoImport {
    static let photoCap = 4

    struct Result {
        let photos: [SharePhoto]
        let failureCount: Int
    }

    static func load(from context: NSExtensionContext) async -> Result {
        var photos: [SharePhoto] = []
        var failures = 0
        for provider in imageProviders(from: context).prefix(photoCap) {
            if let data = await loadPhoto(from: provider) {
                photos.append(SharePhoto(data: data))
            } else {
                failures += 1
            }
        }
        return Result(photos: photos, failureCount: failures)
    }

    private static func imageProviders(from context: NSExtensionContext) -> [NSItemProvider] {
        context.inputItems
            .compactMap { $0 as? NSExtensionItem }
            .flatMap { $0.attachments ?? [] }
            .filter { $0.hasItemConformingToTypeIdentifier(UTType.image.identifier) }
    }

    private static func loadPhoto(from provider: NSItemProvider) async -> Data? {
        let identifier = imageIdentifier(for: provider)
        if let data = await loadFile(from: provider, identifier: identifier) {
            return data
        }
        return await loadData(from: provider, identifier: identifier)
    }

    private static func imageIdentifier(for provider: NSItemProvider) -> String {
        provider.registeredTypeIdentifiers.first { identifier in
            UTType(identifier)?.conforms(to: .image) == true
        } ?? UTType.image.identifier
    }

    private static func loadFile(
        from provider: NSItemProvider,
        identifier: String
    ) async -> Data? {
        await withCheckedContinuation { continuation in
            provider.loadFileRepresentation(forTypeIdentifier: identifier) { url, _ in
                let data = url.flatMap(MomentPhotoImport.downscaledJPEG(from:))
                continuation.resume(returning: data)
            }
        }
    }

    private static func loadData(
        from provider: NSItemProvider,
        identifier: String
    ) async -> Data? {
        await withCheckedContinuation { continuation in
            provider.loadDataRepresentation(forTypeIdentifier: identifier) { data, _ in
                continuation.resume(
                    returning: data.flatMap(MomentPhotoImport.downscaledJPEG(from:))
                )
            }
        }
    }
}

struct SharePhoto: Identifiable {
    let id = UUID()
    let data: Data
}
