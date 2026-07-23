import PhotosUI
import SwiftData
import SwiftUI
import UIKit

/// The moment composer — "Keep a moment", the counterpart of an intention's
/// *let go*. Capture from an aspiration arrives pre-bound; an unbound weekly
/// photo draft asks for its aspiration here, while sharing uses the extension's
/// focused composer. Only the text and aspiration are required; the
/// `occurredAt` picker backdates freely but never
/// past now, the location chip fetches once on an explicit tap, photos
/// downscale on import, and provenance optionally records the metric or project
/// it came from.
/// Passing an existing moment switches to edit; the owning aspiration and
/// `createdAt` never change.
struct MomentFormView: View {
    // Internal, not private: the composer's behavior lives in its own file
    // (`MomentFormActions`), which reads and writes this state — the same
    // cross-file split as `AspirationDetailView`'s section files.
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss
    @Environment(\.openURL) var openURL

    let editing: Moment?
    let choosesAspiration: Bool
    let prompt: String?

    @Query(sort: \Aspiration.createdAt) var allAspirations: [Aspiration]
    @Query(sort: \Metric.createdAt) private var allMetrics: [Metric]
    @Query(sort: \Project.startedAt) private var allProjects: [Project]

    @State var aspiration: Aspiration?
    @State var text: String
    @State var occurredAt: Date
    @State var provenance: MomentProvenance
    @State var principle: Principle?
    @State var latitude: Double?
    @State var longitude: Double?
    @State var placeName: String
    @State var photoData: [PickedPhoto]
    @State var photoItems: [PhotosPickerItem] = []
    @State var photoImportFailureCount: Int
    @State var locationStatus: LocationStatus = .idle
    @State var reader = MomentLocationReader()
    @State var saveTrigger = false
    @State private var photoViewerRoute: MomentPhotoViewerRoute?

    /// Soft cap, enforced here in the composer, never in the schema.
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
        _aspiration = State(initialValue: moment?.aspiration ?? aspiration)
        _text = State(initialValue: moment?.text ?? "")
        _occurredAt = State(initialValue: moment?.occurredAt ?? min(seed.occurredAt, Date.now))
        _provenance = State(
            initialValue: MomentProvenance(
                metric: moment?.metric,
                project: moment?.project ?? project
            )
        )
        _principle = State(initialValue: moment?.principle)
        _latitude = State(initialValue: moment?.latitude)
        _longitude = State(initialValue: moment?.longitude)
        _placeName = State(initialValue: moment?.placeName ?? "")
        let existingPhotos = moment?.photos
            .sorted { $0.sortIndex < $1.sortIndex }
            .map { PickedPhoto(data: $0.data) }
        let seededPhotos = seed.photos.prefix(Self.photoCap).map(PickedPhoto.init(data:))
        _photoData = State(initialValue: existingPhotos ?? seededPhotos)
        _photoImportFailureCount = State(
            initialValue: moment == nil ? seed.importFailureCount : 0
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                if choosesAspiration {
                    aspirationSection
                }
                textSection
                whenSection
                locationSection
                photosSection
                provenanceSection
                if !heldPrinciples.isEmpty {
                    livesSection
                }
            }
            .navigationTitle(editing == nil ? "Keep a Moment" : "Edit Moment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            .sensoryFeedback(.success, trigger: saveTrigger)
            .onChange(of: photoItems) { _, items in
                Task { await loadPhotos(items) }
            }
        }
        .fullScreenCover(item: $photoViewerRoute) { route in
            MomentPhotoViewer(route: route)
        }
    }
}

// MARK: - Provenance & location state

/// The moment's optional source — none, or exactly one metric or project.
/// Hashable so it drives the composer's `Picker` selection.
enum MomentProvenance: Hashable {
    case none
    case metric(Metric)
    case project(Project)

    init(metric: Metric?, project: Project?) {
        if let project {
            self = .project(project)
        } else if let metric {
            self = .metric(metric)
        } else {
            self = .none
        }
    }

    var metric: Metric? {
        if case let .metric(metric) = self { metric } else { nil }
    }

    var project: Project? {
        if case let .project(project) = self { project } else { nil }
    }
}

extension MomentFormView {
    /// The location chip's state — idle, mid-fetch, or blocked after a denied
    /// tap (which earns the footnote, shown only inside this open composer).
    enum LocationStatus {
        case idle
        case resolving
        case denied
    }
}

// MARK: - Text & time

extension MomentFormView {
    private var textSection: some View {
        Section {
            if let prompt {
                Text(prompt)
                    .font(.subheadline.weight(.medium))
                    .fixedSize(horizontal: false, vertical: true)
            }
            TextField(
                prompt == nil ? "What grew out of this?" : "Your reflection",
                text: $text,
                axis: .vertical
            )
            .lineLimit(3 ... 8)
        } header: {
            Text("Moment")
        } footer: {
            Text(momentPrivacyNote)
        }
    }

    private var momentPrivacyNote: String {
        if let aspiration {
            "Kept under \(aspiration.title). Only you will ever read it."
        } else {
            "Choose where this moment belongs. Only you will ever read it."
        }
    }

    private var whenSection: some View {
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

// MARK: - Location

extension MomentFormView {
    private var locationSection: some View {
        Section {
            if hasLocation {
                keptLocationRow
            } else {
                addLocationButton
            }
        } footer: {
            if locationStatus == .denied {
                deniedFootnote
            }
        }
    }

    private var hasLocation: Bool {
        latitude != nil && longitude != nil
    }

    private var placeLabel: String {
        let trimmed = placeName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Location" : trimmed
    }

    private var keptLocationRow: some View {
        HStack {
            Label(placeLabel, systemImage: "mappin.and.ellipse")
            Spacer()
            Button("Remove", role: .destructive, action: removeLocation)
                .font(.caption)
                .buttonStyle(.borderless)
        }
    }

    private var addLocationButton: some View {
        Button(action: resolveLocation) {
            HStack {
                Label("Add location", systemImage: "mappin")
                Spacer()
                if locationStatus == .resolving {
                    ProgressView()
                }
            }
        }
        .disabled(locationStatus == .resolving || locationStatus == .denied)
    }

    private var deniedFootnote: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Location access is off. It's used only to label a moment you choose to keep.")
            Button("Open Settings", action: openSettings)
                .font(.caption)
        }
    }
}

// MARK: - Photos

extension MomentFormView {
    private var photosSection: some View {
        Section {
            if !photoData.isEmpty {
                photoStrip
            }
            if photoData.count < Self.photoCap {
                photoPicker
            }
        } header: {
            Text("Photos")
        } footer: {
            if photoImportFailureCount > 0 {
                Text(importFailureNote)
            }
        }
    }

    /// The visible outcome of a failed import — an iCloud photo that wouldn't
    /// download, an undecodable file — so picked photos never just vanish.
    private var importFailureNote: String {
        photoImportFailureCount == 1
            ? "One photo couldn't be imported."
            : "\(photoImportFailureCount) photos couldn't be imported."
    }

    private var photoStrip: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 10) {
                ForEach(Array(photoData.enumerated()), id: \.element.id) { indexedPhoto in
                    photoThumb(indexedPhoto.element, at: indexedPhoto.offset)
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    @ViewBuilder
    private func photoThumb(_ photo: PickedPhoto, at index: Int) -> some View {
        if let image = UIImage(data: photo.data) {
            ZStack(alignment: .topTrailing) {
                viewPhotoButton(image, at: index)
                removePhotoButton(photo, at: index)
            }
        }
    }

    private func viewPhotoButton(_ image: UIImage, at index: Int) -> some View {
        Button {
            photoViewerRoute = MomentPhotoViewerRoute(
                photos: photoData.map(\.data),
                selectedIndex: index
            )
        } label: {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("View photo \(index + 1) of \(photoData.count)")
        .accessibilityHint("Opens the photo full screen")
    }

    private func removePhotoButton(_ photo: PickedPhoto, at index: Int) -> some View {
        Button {
            removePhoto(photo)
        } label: {
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.white, .black.opacity(0.5))
                .padding(4)
                .frame(width: 44, height: 44, alignment: .topTrailing)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Remove photo \(index + 1) of \(photoData.count)")
        .accessibilityHint("Removes this photo from the moment")
    }

    private var photoPicker: some View {
        PhotosPicker(
            selection: $photoItems,
            maxSelectionCount: Self.photoCap - photoData.count,
            matching: .images
        ) {
            Label("Add photos", systemImage: "photo.on.rectangle")
        }
    }
}

// MARK: - Provenance

extension MomentFormView {
    private var provenanceSection: some View {
        Section {
            Picker("Source", selection: $provenance) {
                Text("None").tag(MomentProvenance.none)
                ForEach(orderedMetrics) { metric in
                    Label(metric.name, systemImage: metric.displayIcon)
                        .tag(MomentProvenance.metric(metric))
                }
                ForEach(orderedProjects) { project in
                    Label(project.name, systemImage: "folder")
                        .tag(MomentProvenance.project(project))
                }
            }
        } header: {
            Text("Where it happened")
        } footer: {
            Text("Optional — the metric or project this moment came from.")
        }
    }

    /// The aspiration's own attachments first, then everything else reachable,
    /// each group keeping the query's creation order.
    private var orderedMetrics: [Metric] {
        allMetrics.filter(isAttachedMetric) + allMetrics.filter { !isAttachedMetric($0) }
    }

    private var orderedProjects: [Project] {
        allProjects.filter(isAttachedProject) + allProjects.filter { !isAttachedProject($0) }
    }

    private func isAttachedMetric(_ metric: Metric) -> Bool {
        aspiration?.metrics.contains { $0 === metric } == true
    }

    private func isAttachedProject(_ project: Project) -> Bool {
        aspiration?.projects.contains { $0 === project } == true
    }
}

// MARK: - Lives

extension MomentFormView {
    /// Present only once the aspiration holds any principles: the vow this
    /// testimony is evidence of. Provenance, never a score — a tagged moment
    /// lights no strip (see `PrincipleLiving`).
    private var livesSection: some View {
        Section {
            Picker("Principle", selection: $principle) {
                Text("None").tag(Principle?.none)
                ForEach(heldPrinciples) { held in
                    Text(held.text).tag(Principle?.some(held))
                }
            }
        } header: {
            Text("Lives a principle")
        } footer: {
            Text("Optional — the vow this moment is evidence of.")
        }
    }

    private var heldPrinciples: [Principle] {
        (aspiration?.principles ?? []).sorted { $0.createdAt < $1.createdAt }
    }
}
