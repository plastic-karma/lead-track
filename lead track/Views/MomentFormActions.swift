import PhotosUI
import SwiftData
import SwiftUI
import UIKit

// The composer's behavior, split from its layout in `MomentFormView`: the
// toolbar, photo import (downscaled off the picker), the one-shot location
// fetch, and the save that reconciles the moment and its photo children.

// MARK: - Picked photos

extension MomentFormView {
    /// One imported photo in the composer. Identity is the import itself, not
    /// the array slot, so the strip's `ForEach` diffs a mid-strip delete as
    /// the removal of that one thumbnail rather than a content change of
    /// every later one.
    struct PickedPhoto: Identifiable {
        let id = UUID()
        let data: Data
    }
}

// MARK: - Toolbar & actions

extension MomentFormView {
    @ToolbarContentBuilder
    var toolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("Keep", action: save)
                .disabled(trimmedText.isEmpty)
        }
    }

    private var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Imports the picker selection, counting the items that fail to load or
    /// decode so the photos section can say so instead of silently showing
    /// fewer thumbnails than were picked.
    func loadPhotos(_ items: [PhotosPickerItem]) async {
        var failures = 0
        for item in items where photoData.count < Self.photoCap {
            if let data = await downscaledData(from: item) {
                photoData.append(PickedPhoto(data: data))
            } else {
                failures += 1
            }
        }
        photoImportFailureCount = failures
        photoItems = []
    }

    private func downscaledData(from item: PhotosPickerItem) async -> Data? {
        guard let raw = try? await item.loadTransferable(type: Data.self) else { return nil }
        return MomentPhotoImport.downscaledJPEG(from: raw)
    }

    func removePhoto(_ photo: PickedPhoto) {
        photoData.removeAll { $0.id == photo.id }
    }

    func resolveLocation() {
        locationStatus = .resolving
        Task {
            applyLocation(await reader.resolve())
        }
    }

    private func applyLocation(_ outcome: MomentLocationReader.Outcome) {
        switch outcome {
        case let .resolved(place):
            latitude = place.latitude
            longitude = place.longitude
            placeName = place.name
            locationStatus = .idle
        case .denied:
            locationStatus = .denied
        case .failed:
            locationStatus = .idle
        }
    }

    func removeLocation() {
        latitude = nil
        longitude = nil
        placeName = ""
        locationStatus = .idle
    }

    func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }
}

// MARK: - Save

extension MomentFormView {
    func save() {
        let moment = editing ?? Moment(text: trimmedText, aspiration: aspiration)
        moment.text = trimmedText
        moment.occurredAt = occurredAt
        moment.metric = provenance.metric
        moment.project = provenance.project
        moment.principle = principle
        moment.latitude = latitude
        moment.longitude = longitude
        moment.placeName = placeName
        if editing == nil {
            modelContext.insert(moment)
        }
        syncPhotos(of: moment)
        saveTrigger.toggle()
        dismiss()
    }

    /// Rebuilds the photo children only when the set actually changed, so a
    /// no-op edit never churns external blobs. Cascade means old photos are
    /// explicitly deleted before the new set is inserted.
    private func syncPhotos(of moment: Moment) {
        let existing = moment.photos.sorted { $0.sortIndex < $1.sortIndex }
        guard existing.map(\.data) != photoData.map(\.data) else { return }
        for photo in existing {
            modelContext.delete(photo)
        }
        for (index, photo) in photoData.enumerated() {
            modelContext.insert(MomentPhoto(data: photo.data, sortIndex: index, moment: moment))
        }
    }
}
