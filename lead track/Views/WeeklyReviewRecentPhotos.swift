import Photos
import SwiftUI
import UIKit

// MARK: - Recent-photo picker

struct RecentMomentPhotoPicker: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    let window: RecentPhotoWindow
    let prepare: (WeeklyMomentPhotoDraft) -> Void

    @State private var library = RecentMomentPhotoLibrary()
    @State private var selection: [RecentMomentPhotoLibrary.Photo] = []
    @State private var isImporting = false
    @State private var importFailureCount = 0

    private let columns = [GridItem(.adaptive(minimum: 96), spacing: 4)]

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Photos from the Last 7 Days")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbar }
        }
        .interactiveDismissDisabled(isImporting)
        .task { library.refresh(in: window) }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { library.refresh(in: window) }
        }
        .onChange(of: library.photos) { _, photos in
            pruneSelection(to: photos)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch library.accessState {
        case .notDetermined:
            accessRequest
        case .requesting:
            ProgressView("Opening your photo library…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .authorized, .limited:
            accessiblePhotos
        case .denied:
            deniedAccess
        case .restricted:
            restrictedAccess
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { dismiss() }
                .disabled(isImporting)
        }
        ToolbarItem(placement: .confirmationAction) {
            Button(action: startImport) {
                if isImporting {
                    ProgressView()
                } else {
                    Text("Continue")
                }
            }
            .disabled(selection.isEmpty || !library.accessState.canRead || isImporting)
        }
    }
}

// MARK: - Access states

private extension RecentMomentPhotoPicker {
    var accessRequest: some View {
        ContentUnavailableView {
            Label("Photos from the last 7 days", systemImage: "photo.stack")
        } description: {
            Text("Allow photo access to show only the days covered by this review.")
        } actions: {
            Button("Continue") {
                Task { await library.requestAccess(in: window) }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    var deniedAccess: some View {
        ContentUnavailableView {
            Label("Photo access is off", systemImage: "photo.badge.exclamationmark")
        } description: {
            Text("Turn on access in Settings to choose photos from this review.")
        } actions: {
            Button("Open Settings", action: openSettings)
                .buttonStyle(.bordered)
        }
    }

    var restrictedAccess: some View {
        ContentUnavailableView {
            Label("Photos unavailable", systemImage: "photo.badge.exclamationmark")
        } description: {
            Text("Photo library access is restricted on this device.")
        }
    }

    func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }
}

// MARK: - Selection

private extension RecentMomentPhotoPicker {
    @ViewBuilder
    var accessiblePhotos: some View {
        if library.photos.isEmpty {
            noRecentPhotos
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if library.accessState == .limited {
                        limitedAccessNote
                    }
                    LazyVGrid(columns: columns, spacing: 4) {
                        ForEach(library.photos) { photo in
                            photoButton(photo)
                        }
                    }
                    if importFailureCount > 0 {
                        Text(importFailureNote)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
            }
        }
    }

    var noRecentPhotos: some View {
        ContentUnavailableView {
            Label("No recent photos", systemImage: "photo")
        } description: {
            Text(emptyPhotosDescription)
        } actions: {
            if library.accessState == .limited {
                Button("Manage Access", action: openSettings)
                    .buttonStyle(.bordered)
            }
        }
    }

    var limitedAccessNote: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Showing photos LeadStone can access.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Manage Access", action: openSettings)
                .font(.caption)
        }
    }

    var emptyPhotosDescription: String {
        if library.accessState == .limited {
            "No accessible photos were taken in the last 7 days."
        } else {
            "No photos were taken in the last 7 days."
        }
    }

    var importFailureNote: String {
        importFailureCount == 1
            ? "The selected photo couldn't be imported."
            : "The selected photos couldn't be imported."
    }

    func photoButton(_ photo: RecentMomentPhotoLibrary.Photo) -> some View {
        let selectedIndex = selection.firstIndex(of: photo)
        return Button {
            toggle(photo)
        } label: {
            RecentMomentPhotoThumbnail(
                photo: photo,
                library: library,
                selectionNumber: selectedIndex.map { $0 + 1 }
            )
        }
        .buttonStyle(.plain)
        .disabled(selectedIndex == nil && selection.count >= MomentFormView.photoCap)
        .opacity(selectedIndex == nil && selection.count >= MomentFormView.photoCap ? 0.45 : 1)
        .accessibilityLabel(photo.creationDate.formatted(date: .abbreviated, time: .shortened))
        .accessibilityValue(selectedIndex.map { "Selected \($0 + 1)" } ?? "Not selected")
    }

    func toggle(_ photo: RecentMomentPhotoLibrary.Photo) {
        if let index = selection.firstIndex(of: photo) {
            selection.remove(at: index)
        } else if selection.count < MomentFormView.photoCap {
            selection.append(photo)
        }
        importFailureCount = 0
    }

    func pruneSelection(to photos: [RecentMomentPhotoLibrary.Photo]) {
        let availableIDs = Set(photos.map(\.id))
        selection.removeAll { !availableIDs.contains($0.id) }
        importFailureCount = 0
    }
}

// MARK: - Import

private extension RecentMomentPhotoPicker {
    func startImport() {
        isImporting = true
        Task { await finishImport() }
    }

    func finishImport() async {
        let result = await library.importPhotos(selection)
        isImporting = false
        guard !result.photos.isEmpty else {
            importFailureCount = result.failureCount
            return
        }
        prepare(WeeklyMomentPhotoDraft(
            photos: result.photos,
            occurredAt: min(result.occurredAt ?? .now, .now),
            failureCount: result.failureCount
        ))
    }
}
