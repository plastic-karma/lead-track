import PhotosUI
import SwiftData
import SwiftUI
import UIKit

/// The moment composer — "Keep a moment", the counterpart of an intention's
/// *let go*. Always born with its aspiration (capture only ever starts from an
/// aspiration surface), so there is no aspiration picker. Only the text is
/// required; the `occurredAt` picker backdates freely but never past now, the
/// location chip fetches once on an explicit tap, photos downscale on import,
/// and provenance optionally records the metric or project it came from.
/// Passing an existing moment switches to edit; the owning aspiration and
/// `createdAt` never change.
struct MomentFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    let aspiration: Aspiration
    private let editing: Moment?

    @Query(sort: \Metric.createdAt) private var allMetrics: [Metric]
    @Query(sort: \Project.startedAt) private var allProjects: [Project]

    @State private var text: String
    @State private var occurredAt: Date
    @State private var provenance: MomentProvenance
    @State private var latitude: Double?
    @State private var longitude: Double?
    @State private var placeName: String
    @State private var photoData: [Data]
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var locationStatus: LocationStatus = .idle
    @State private var reader = MomentLocationReader()
    @State private var saveTrigger = false

    /// Soft cap, enforced here in the composer, never in the schema.
    static let photoCap = 4

    init(aspiration: Aspiration, moment: Moment? = nil) {
        self.aspiration = aspiration
        editing = moment
        _text = State(initialValue: moment?.text ?? "")
        _occurredAt = State(initialValue: moment?.occurredAt ?? .now)
        _provenance = State(
            initialValue: MomentProvenance(metric: moment?.metric, project: moment?.project)
        )
        _latitude = State(initialValue: moment?.latitude)
        _longitude = State(initialValue: moment?.longitude)
        _placeName = State(initialValue: moment?.placeName ?? "")
        _photoData = State(
            initialValue: (moment?.photos ?? [])
                .sorted { $0.sortIndex < $1.sortIndex }
                .map(\.data)
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                textSection
                whenSection
                locationSection
                photosSection
                provenanceSection
            }
            .navigationTitle(editing == nil ? "Keep a Moment" : "Edit Moment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            .sensoryFeedback(.success, trigger: saveTrigger)
            .onChange(of: photoItems) { _, items in
                Task { await loadPhotos(items) }
            }
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
            TextField("What grew out of this?", text: $text, axis: .vertical)
                .lineLimit(3 ... 8)
        } header: {
            Text("Moment")
        } footer: {
            Text("Kept under \(aspiration.title). Only you will ever read it.")
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
        Section("Photos") {
            if !photoData.isEmpty {
                photoStrip
            }
            if photoData.count < Self.photoCap {
                photoPicker
            }
        }
    }

    private var photoStrip: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 10) {
                ForEach(Array(photoData.enumerated()), id: \.offset) { index, data in
                    photoThumb(data, index: index)
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    @ViewBuilder
    private func photoThumb(_ data: Data, index: Int) -> some View {
        if let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(alignment: .topTrailing) {
                    Button {
                        removePhoto(at: index)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.white, .black.opacity(0.5))
                    }
                    .padding(4)
                }
        }
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
        aspiration.metrics.contains { $0 === metric }
    }

    private func isAttachedProject(_ project: Project) -> Bool {
        aspiration.projects.contains { $0 === project }
    }
}
