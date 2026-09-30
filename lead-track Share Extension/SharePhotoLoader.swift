import Foundation
import Observation

/// Owns the extension request for exactly as long as its custom composer is on
/// screen. Completion returns to Photos only after the shared store saves.
@MainActor
@Observable
final class SharePhotoLoader {
    enum State: Equatable {
        case idle
        case loading
        case loaded
    }

    private(set) var photos: [SharePhoto] = []
    private(set) var failureCount = 0
    private(set) var state = State.idle

    private let extensionContext: NSExtensionContext

    init(extensionContext: NSExtensionContext) {
        self.extensionContext = extensionContext
    }

    func load() async {
        guard state == .idle else { return }
        state = .loading
        let result = await SharePhotoImport.load(from: extensionContext)
        photos = result.photos
        failureCount = result.failureCount
        state = .loaded
    }

    func remove(_ photo: SharePhoto) {
        photos.removeAll { $0.id == photo.id }
    }

    func cancel() {
        extensionContext.cancelRequest(withError: CocoaError(.userCancelled))
    }

    func finish() {
        extensionContext.completeRequest(returningItems: [], completionHandler: nil)
    }
}
