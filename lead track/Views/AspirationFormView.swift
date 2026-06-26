import PhotosUI
import SwiftData
import SwiftUI
import UIKit

/// Create or edit an aspiration: title, why-text, icon, color, cover photo, and
/// the attach picker. Passing an existing aspiration switches to edit; `nil`
/// creates a new one. Membership is fully editable here.
struct AspirationFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    private let editing: Aspiration?
    @State private var title: String
    @State private var detail: String
    @State private var icon: String
    @State private var color: MetricColor
    @State private var imageData: Data?
    @State private var photoItem: PhotosPickerItem?
    @State private var selectedMetrics: Set<Metric>
    @State private var selectedProjects: Set<Project>
    @State private var saveTrigger = false

    private let iconOptions = [
        "mountain.2", "sparkles", "star", "heart", "leaf",
        "flame", "book", "figure.run", "brain.head.profile"
    ]

    init(aspiration: Aspiration? = nil) {
        editing = aspiration
        _title = State(initialValue: aspiration?.title ?? "")
        _detail = State(initialValue: aspiration?.detail ?? "")
        _icon = State(initialValue: aspiration?.displayIcon ?? "mountain.2")
        _color = State(initialValue: MetricColor(rawValue: aspiration?.colorName ?? "") ?? .copper)
        _imageData = State(initialValue: aspiration?.imageData)
        _selectedMetrics = State(initialValue: Set(aspiration?.metrics ?? []))
        _selectedProjects = State(initialValue: Set(aspiration?.projects ?? []))
    }

    var body: some View {
        NavigationStack {
            Form {
                detailsSection
                appearanceSection
                coverSection
                AspirationAttachPicker(
                    selectedMetrics: $selectedMetrics,
                    selectedProjects: $selectedProjects
                )
            }
            .navigationTitle(editing == nil ? "New Aspiration" : "Edit Aspiration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            .sensoryFeedback(.success, trigger: saveTrigger)
            .onChange(of: photoItem) { _, item in
                Task { await loadPhoto(item) }
            }
        }
    }
}

// MARK: - Sections

extension AspirationFormView {
    private var detailsSection: some View {
        Section {
            TextField("Title", text: $title)
            TextField("Why this matters", text: $detail, axis: .vertical)
                .lineLimit(3 ... 6)
        }
    }

    private var appearanceSection: some View {
        Section("Appearance") {
            IconGridPicker(options: iconOptions, selection: $icon)
            ColorGridPicker(selection: $color)
        }
    }

    private var coverSection: some View {
        Section("Cover") {
            if let image = currentCover {
                image
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 140)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .listRowInsets(EdgeInsets())
            }
            PhotosPicker(selection: $photoItem, matching: .images) {
                Label(
                    imageData == nil ? "Choose Photo" : "Change Photo",
                    systemImage: "photo"
                )
            }
            if imageData != nil {
                Button("Remove Photo", role: .destructive, action: removePhoto)
            }
        }
    }

    private var currentCover: Image? {
        guard let data = imageData, let uiImage = UIImage(data: data) else {
            return nil
        }
        return Image(uiImage: uiImage)
    }
}

// MARK: - Toolbar & actions

extension AspirationFormView {
    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("Save", action: save)
                .disabled(trimmedTitle.isEmpty)
        }
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func loadPhoto(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        imageData = try? await item.loadTransferable(type: Data.self)
    }

    private func removePhoto() {
        imageData = nil
        photoItem = nil
    }

    private func save() {
        let aspiration = editing ?? Aspiration(title: trimmedTitle)
        aspiration.title = trimmedTitle
        aspiration.detail = detail
        aspiration.icon = icon
        aspiration.colorName = color.rawValue
        aspiration.imageData = imageData
        aspiration.metrics = Array(selectedMetrics)
        aspiration.projects = Array(selectedProjects)
        if editing == nil {
            modelContext.insert(aspiration)
        }
        saveTrigger.toggle()
        dismiss()
    }
}
