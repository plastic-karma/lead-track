import Foundation
import Observation
import Photos
import UIKit

/// The deliberately short-lived PhotoKit reader behind the Week tab's recent
/// photo chooser. It asks for library access only after the user opens that
/// chooser, fetches image assets inside the exact reviewed window, and keeps
/// PhotoKit identifiers transient — only stripped, downscaled JPEG bytes cross
/// into a `Moment` draft.
@MainActor
@Observable
final class RecentMomentPhotoLibrary {
    enum AccessState: Equatable {
        case notDetermined
        case requesting
        case authorized
        case limited
        case denied
        case restricted

        var canRead: Bool {
            self == .authorized || self == .limited
        }
    }

    struct Photo: Identifiable, Hashable {
        let id: String
        let creationDate: Date
    }

    struct ImportResult {
        let photos: [Data]
        let occurredAt: Date?
        let failureCount: Int
    }

    private(set) var accessState: AccessState
    private(set) var photos: [Photo] = []

    private let imageManager = PHCachingImageManager()
    private var assetsByID: [String: PHAsset] = [:]

    init() {
        accessState = Self.accessState(
            for: PHPhotoLibrary.authorizationStatus(for: .readWrite)
        )
    }

    /// Refreshes only when access already exists. Merely opening Week therefore
    /// never earns a Photos permission prompt.
    func refresh(in window: RecentPhotoWindow) {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        apply(status, in: window)
    }

    /// Called only by the explicit access button inside the chooser.
    func requestAccess(in window: RecentPhotoWindow) async {
        accessState = .requesting
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        apply(status, in: window)
    }

    @discardableResult
    func requestThumbnail(
        for photo: Photo,
        targetSize: CGSize,
        completion: @escaping @MainActor (UIImage?) -> Void
    ) -> PHImageRequestID? {
        guard let asset = assetsByID[photo.id] else {
            completion(nil)
            return nil
        }
        let options = thumbnailOptions()
        return imageManager.requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: options
        ) { image, info in
            guard !Self.isDegraded(info) else { return }
            Task { @MainActor in completion(image) }
        }
    }

    func cancelThumbnail(_ requestID: PHImageRequestID) {
        imageManager.cancelImageRequest(requestID)
    }

    /// Imports one selection at a time. This preserves chronological ordering
    /// without inflating several full camera originals in memory together.
    func importPhotos(_ selection: [Photo]) async -> ImportResult {
        let ordered = selection.sorted { $0.creationDate < $1.creationDate }
        var imported: [Data] = []
        var importedDates: [Date] = []
        var failures = 0
        for photo in ordered {
            guard let data = await importedData(for: photo) else {
                failures += 1
                continue
            }
            imported.append(data)
            importedDates.append(photo.creationDate)
        }
        return ImportResult(
            photos: imported,
            occurredAt: importedDates.min(),
            failureCount: failures
        )
    }
}

// MARK: - Authorization & fetch

private extension RecentMomentPhotoLibrary {
    static func accessState(for status: PHAuthorizationStatus) -> AccessState {
        switch status {
        case .notDetermined: .notDetermined
        case .authorized: .authorized
        case .limited: .limited
        case .denied: .denied
        case .restricted: .restricted
        @unknown default: .restricted
        }
    }

    func apply(_ status: PHAuthorizationStatus, in window: RecentPhotoWindow) {
        accessState = Self.accessState(for: status)
        guard accessState.canRead else {
            clearPhotos()
            return
        }
        fetchPhotos(in: window)
    }

    func fetchPhotos(in window: RecentPhotoWindow) {
        let options = PHFetchOptions()
        options.predicate = NSPredicate(
            format: "creationDate >= %@ AND creationDate < %@",
            window.start as NSDate,
            window.end as NSDate
        )
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let result = PHAsset.fetchAssets(with: .image, options: options)
        var fetchedPhotos: [Photo] = []
        var fetchedAssets: [String: PHAsset] = [:]
        result.enumerateObjects { asset, _, _ in
            guard let creationDate = asset.creationDate, window.contains(creationDate)
            else { return }
            fetchedPhotos.append(Photo(id: asset.localIdentifier, creationDate: creationDate))
            fetchedAssets[asset.localIdentifier] = asset
        }
        photos = fetchedPhotos
        assetsByID = fetchedAssets
    }

    func clearPhotos() {
        photos = []
        assetsByID = [:]
    }
}

// MARK: - Image requests

private extension RecentMomentPhotoLibrary {
    func thumbnailOptions() -> PHImageRequestOptions {
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        return options
    }

    func importedData(for photo: Photo) async -> Data? {
        guard !Task.isCancelled, let asset = assetsByID[photo.id] else { return nil }
        guard let original = await imageData(for: asset) else { return nil }
        return MomentPhotoImport.downscaledJPEG(from: original)
    }

    func imageData(for asset: PHAsset) async -> Data? {
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.version = .current
        options.isNetworkAccessAllowed = true
        return await withCheckedContinuation { continuation in
            imageManager.requestImageDataAndOrientation(for: asset, options: options) { data, _, _, _ in
                continuation.resume(returning: data)
            }
        }
    }

    nonisolated static func isDegraded(_ info: [AnyHashable: Any]?) -> Bool {
        info?[PHImageResultIsDegradedKey] as? Bool == true
    }
}
