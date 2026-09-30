import PhotosUI
import SwiftData
import SwiftUI
import UIKit

/// Keep or edit a moment without changing its owning aspiration or creation date.
struct MomentFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    private let editing: Moment?
    private let choosesAspiration: Bool
    private let prompt: String?
    private let seed: MomentFormSeed

    @State private var aspiration: Aspiration?
    @State private var text: String
    @State private var occurredAt: Date
    @State private var provenance: MomentProvenance
    @State private var principle: Principle?
    @State private var latitude: Double?
    @State private var longitude: Double?
    @State private var placeName: String
    @State private var photoData: [PickedPhoto] = []
    @State private var didInitializePhotos = false
    @State private var photoImportFailureCount: Int
    @State private var locationStatus: MomentLocationStatus = .idle
    @State private var reader: MomentLocationReader?
    @State private var saveTrigger = false
    @State private var photoViewerRoute: MomentPhotoViewerRoute?

    /// Soft cap enforced only for imports, never existing saved photos.
    static let photoCap = 4

    init(
        aspiration: Aspiration? = nil,
        project: Project? = nil,
        moment: Moment? = nil,
        prompt: String? = nil,
        seed: MomentFormSeed = MomentFormSeed()
    ) {
        editing = moment
        choosesAspiration = moment == nil && aspiration == nil
        self.prompt = prompt
        self.seed = seed
        _aspiration = State(initialValue: moment?.aspiration ?? aspiration)
        _text = State(initialValue: moment?.text ?? "")
        _occurredAt = State(initialValue: moment?.occurredAt ?? min(seed.occurredAt, Date.now))
        _provenance = State(initialValue: MomentProvenance(metric: moment?.metric, project: moment?.project ?? project))
        _principle = State(initialValue: moment?.principle)
        _latitude = State(initialValue: moment?.latitude)
        _longitude = State(initialValue: moment?.longitude)
        _placeName = State(initialValue: moment?.placeName ?? "")
        _photoImportFailureCount = State(initialValue: moment == nil ? seed.importFailureCount : 0)
    }

    var body: some View {
        NavigationStack {
            Form {
                if choosesAspiration {
                    MomentAspirationSection(aspiration: $aspiration, principle: $principle)
                }
                MomentTextSection(text: $text, prompt: prompt, aspirationTitle: aspiration?.title)
                MomentWhenSection(occurredAt: $occurredAt)
                MomentLocationSection(
                    hasLocation: latitude != nil && longitude != nil,
                    placeName: placeName, status: locationStatus,
                    onRemove: removeLocation, onResolve: resolveLocation, onSettings: openSettings
                )
                MomentPhotosSection(
                    photos: photoData, failureCount: photoImportFailureCount,
                    onRemove: removePhoto, onView: viewPhoto, onImport: loadPhotos
                )
                MomentProvenanceSection(aspiration: aspiration, provenance: $provenance)
                MomentPrincipleSection(aspiration: aspiration, principle: $principle)
            }
            .navigationTitle(editing == nil ? "Keep a Moment" : "Edit Moment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Keep", action: save)
                        .disabled(trimmedText.isEmpty || !hasAvailableOwner || !didInitializePhotos)
                }
            }
            .sensoryFeedback(.success, trigger: saveTrigger)
            .onAppear(perform: initializePhotos)
        }
        .fullScreenCover(item: $photoViewerRoute) { MomentPhotoViewer(route: $0) }
    }

    private var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var hasAvailableOwner: Bool {
        guard let aspiration else { return false }
        return editing != nil || !aspiration.isArchived
    }

    private func initializePhotos() {
        guard !didInitializePhotos else { return }
        if let editing {
            photoData = editing.photos.sorted { $0.sortIndex < $1.sortIndex }
                .map { PickedPhoto(data: $0.data) }
        } else {
            photoData = seed.photos.prefix(Self.photoCap).map(PickedPhoto.init(data:))
        }
        didInitializePhotos = true
    }

    private func loadPhotos(_ items: [PhotosPickerItem]) async {
        var failures = 0
        for item in items where photoData.count < Self.photoCap {
            if let data = await downscaledData(from: item) {
                photoData.append(PickedPhoto(data: data))
            } else {
                failures += 1
            }
        }
        photoImportFailureCount = failures
    }

    private func downscaledData(from item: PhotosPickerItem) async -> Data? {
        guard let raw = try? await item.loadTransferable(type: Data.self) else { return nil }
        return MomentPhotoImport.downscaledJPEG(from: raw)
    }

    private func removePhoto(_ photo: PickedPhoto) {
        photoData.removeAll { $0.id == photo.id }
    }

    private func viewPhoto(_ photo: PickedPhoto) {
        guard let index = photoData.firstIndex(where: { $0.id == photo.id }) else { return }
        photoViewerRoute = MomentPhotoViewerRoute(photos: photoData.map(\.data), selectedIndex: index)
    }

    private func resolveLocation() {
        let reader = reader ?? MomentLocationReader()
        self.reader = reader
        locationStatus = .resolving
        Task { applyLocation(await reader.resolve()) }
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

    private func removeLocation() {
        latitude = nil
        longitude = nil
        placeName = ""
        locationStatus = .idle
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }

    private func save() {
        guard didInitializePhotos, let aspiration, hasAvailableOwner, !trimmedText.isEmpty else { return }
        let moment = editing ?? Moment(text: trimmedText, aspiration: aspiration)
        moment.text = trimmedText
        moment.occurredAt = occurredAt
        moment.metric = provenance.metric
        moment.project = provenance.project
        moment.principle = principle
        moment.latitude = latitude
        moment.longitude = longitude
        moment.placeName = placeName
        if editing == nil { modelContext.insert(moment) }
        MomentPhotoReconciler.sync(photoData.map(\.data), with: moment, in: modelContext)
        saveTrigger.toggle()
        dismiss()
    }
}

/// Identity belongs to the imported occurrence, never its bytes or array slot.
private struct PickedPhoto: Identifiable {
    let id = UUID()
    let data: Data
}

/// Exactly one optional source for the composer's picker.
enum MomentProvenance: Hashable {
    case none
    case metric(Metric)
    case project(Project)

    init(metric: Metric?, project: Project?) {
        if let project { self = .project(project) }
        else if let metric { self = .metric(metric) }
        else { self = .none }
    }

    var metric: Metric? {
        if case let .metric(metric) = self { metric } else { nil }
    }

    var project: Project? {
        if case let .project(project) = self { project } else { nil }
    }
}

private enum MomentLocationStatus: Equatable {
    case idle, resolving, denied
}

private struct MomentAspirationSection: View {
    @Query(sort: \Aspiration.createdAt) private var allAspirations: [Aspiration]
    @Binding var aspiration: Aspiration?
    @Binding var principle: Principle?

    var body: some View {
        let choices = allAspirations.unarchived.inDisplayOrder
        Section {
            Picker("Aspiration", selection: aspirationSelection) {
                Text("Choose an aspiration").tag(Aspiration?.none)
                ForEach(choices) { option in
                    Label(option.title, systemImage: option.displayIcon).tag(Aspiration?.some(option))
                }
            }
        } footer: {
            if choices.isEmpty {
                Text("Create or bring back an aspiration before keeping this moment.")
            }
        }
        .onChange(of: aspiration?.isArchived) { _, archived in
            if archived == true {
                aspiration = nil
                principle = nil
            }
        }
    }

    private var aspirationSelection: Binding<Aspiration?> {
        Binding(
            get: { aspiration },
            set: { selected in
                aspiration = selected
                principle = nil
            }
        )
    }
}

private struct MomentTextSection: View {
    @Binding var text: String
    let prompt: String?
    let aspirationTitle: String?

    var body: some View {
        Section {
            if let prompt {
                Text(prompt).font(.subheadline.weight(.medium))
                    .fixedSize(horizontal: false, vertical: true)
            }
            TextField(prompt == nil ? "What grew out of this?" : "Your reflection", text: $text, axis: .vertical)
                .lineLimit(3 ... 8)
        } header: {
            Text("Moment")
        } footer: {
            if let aspirationTitle {
                Text("Kept under \(aspirationTitle). Only you will ever read it.")
            } else {
                Text("Choose where this moment belongs. Only you will ever read it.")
            }
        }
    }
}

private struct MomentWhenSection: View {
    @Binding var occurredAt: Date

    var body: some View {
        Section("When") {
            DatePicker(
                "When it happened",
                selection: $occurredAt,
                in: ...Date.now,
                displayedComponents: [.date, .hourAndMinute]
            )
        }
    }
}

private struct MomentLocationSection: View {
    let hasLocation: Bool
    let placeName: String
    let status: MomentLocationStatus
    let onRemove: () -> Void
    let onResolve: () -> Void
    let onSettings: () -> Void

    var body: some View {
        Section {
            if hasLocation {
                HStack {
                    let trimmed = placeName.trimmingCharacters(in: .whitespacesAndNewlines)
                    Label(trimmed.isEmpty ? "Location" : trimmed, systemImage: "mappin.and.ellipse")
                    Spacer()
                    Button("Remove", role: .destructive, action: onRemove)
                        .font(.caption).buttonStyle(.borderless)
                }
            } else {
                Button(action: onResolve) {
                    HStack {
                        Label("Add location", systemImage: "mappin")
                        Spacer()
                        if status == .resolving { ProgressView() }
                    }
                }
                .disabled(status == .resolving || status == .denied)
            }
        } footer: {
            if status == .denied {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Location access is off. It's used only to label a moment you choose to keep.")
                    Button("Open Settings", action: onSettings).font(.caption)
                }
            }
        }
    }
}

private struct MomentPhotosSection: View {
    let photos: [PickedPhoto]
    let failureCount: Int
    let onRemove: (PickedPhoto) -> Void
    let onView: (PickedPhoto) -> Void
    let onImport: ([PhotosPickerItem]) async -> Void
    @State private var items: [PhotosPickerItem] = []

    var body: some View {
        Section {
            if !photos.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 10) {
                        ForEach(photos.enumerated(), id: \.element.id) { index, photo in
                            MomentPickedPhotoCell(
                                photo: photo, number: index + 1, count: photos.count,
                                onRemove: onRemove, onView: onView
                            )
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
            if photos.count < MomentFormView.photoCap {
                PhotosPicker(
                    selection: $items,
                    maxSelectionCount: MomentFormView.photoCap - photos.count,
                    matching: .images
                ) {
                    Label("Add photos", systemImage: "photo.on.rectangle")
                }
            }
        } header: {
            Text("Photos")
        } footer: {
            if failureCount == 1 {
                Text("One photo couldn't be imported.")
            } else if failureCount > 1 {
                Text("\(failureCount) photos couldn't be imported.")
            }
        }
        .onChange(of: items) { _, selected in
            guard !selected.isEmpty else { return }
            Task {
                await onImport(selected)
                items = []
            }
        }
    }
}

private struct MomentPickedPhotoCell: View {
    let photo: PickedPhoto
    let number: Int
    let count: Int
    let onRemove: (PickedPhoto) -> Void
    let onView: (PickedPhoto) -> Void
    @State private var image: UIImage?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if let image {
                Button { onView(photo) } label: {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 72, height: 72)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("View photo \(number) of \(count)")
                .accessibilityHint("Opens the photo full screen")
                Button { onRemove(photo) } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.white, .black.opacity(0.5))
                        .padding(4)
                        .frame(width: 44, height: 44, alignment: .topTrailing)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove photo \(number) of \(count)")
                .accessibilityHint("Removes this photo from the moment")
            }
        }
        .task(id: photo.data) { image = UIImage(data: photo.data) }
    }
}

private struct MomentProvenanceSection: View {
    @Query(sort: \Metric.createdAt) private var allMetrics: [Metric]
    @Query(sort: \Project.startedAt) private var allProjects: [Project]
    let aspiration: Aspiration?
    @Binding var provenance: MomentProvenance

    var body: some View {
        let metrics = allMetrics.filter(isAttachedMetric) + allMetrics.filter { !isAttachedMetric($0) }
        let projects = allProjects.filter(isAttachedProject) + allProjects.filter { !isAttachedProject($0) }
        Section {
            Picker("Source", selection: $provenance) {
                Text("None").tag(MomentProvenance.none)
                ForEach(metrics) { metric in
                    Label(metric.name, systemImage: metric.displayIcon).tag(MomentProvenance.metric(metric))
                }
                ForEach(projects) { project in
                    Label(project.name, systemImage: "folder").tag(MomentProvenance.project(project))
                }
            }
        } header: {
            Text("Where it happened")
        } footer: {
            Text("Optional — the metric or project this moment came from.")
        }
    }

    private func isAttachedMetric(_ metric: Metric) -> Bool {
        aspiration?.metrics.contains { $0 === metric } == true
    }

    private func isAttachedProject(_ project: Project) -> Bool {
        aspiration?.projects.contains { $0 === project } == true
    }
}

private struct MomentPrincipleSection: View {
    let aspiration: Aspiration?
    @Binding var principle: Principle?

    var body: some View {
        let principles = (aspiration?.principles ?? []).sorted { $0.createdAt < $1.createdAt }
        if !principles.isEmpty {
            Section {
                Picker("Principle", selection: $principle) {
                    Text("None").tag(Principle?.none)
                    ForEach(principles) { held in Text(held.text).tag(Principle?.some(held)) }
                }
            } header: {
                Text("Lives a principle")
            } footer: {
                Text("Optional — the vow this moment is evidence of.")
            }
        }
    }
}
