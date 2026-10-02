import PhotosUI
import SwiftData
import SwiftUI
import UIKit

/// Create or edit an aspiration as it will read: a full-bleed cover, the icon and
/// title inline beneath it, the "why", the color row, and the card-based "what
/// feeds this" picker — all editable in place. Passing an existing aspiration
/// switches to edit; `nil` creates a new one.
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
    @State private var showingPhotoPicker = false
    @State private var showingPhotoLoadFailure = false
    @State private var saveTrigger = false

    private static let iconOptions = [
        "mountain.2", "sparkles", "star", "heart", "leaf",
        "flame", "book", "figure.run", "brain.head.profile",
        "trophy", "target", "crown",
        "globe", "sun.max", "moon.stars",
        "lightbulb", "wand.and.stars", "flag",
        "hands.sparkles", "figure.mind.and.body", "graduationcap",
        "bolt.heart", "hare", "tree"
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
            ZStack {
                Theme.screenBackground.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        AspirationEditorCover(imageData: imageData, tint: color.color)
                        VStack(alignment: .leading, spacing: 28) {
                            AspirationEditorHeading(
                                title: $title, icon: $icon, color: color, iconOptions: Self.iconOptions
                            )
                            AspirationEditorWhy(detail: $detail, tint: color.color)
                            AspirationEditorColor(color: $color)
                            AspirationFeedPicker(
                                selectedMetrics: $selectedMetrics,
                                selectedProjects: $selectedProjects,
                                tint: color.color,
                                prominentTint: color.prominentColor
                            )
                        }
                        .frame(maxWidth: 680, alignment: .leading)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 40)
                    }
                }
                .scrollIndicators(.hidden)
                .ignoresSafeArea(edges: .top)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
            .photosPicker(isPresented: $showingPhotoPicker, selection: $photoItem, matching: .images)
            .sensoryFeedback(.success, trigger: saveTrigger)
            .modifier(AspirationCoverImport(
                photoItem: $photoItem, imageData: $imageData,
                showingPhotoLoadFailure: $showingPhotoLoadFailure
            ))
            .alert("Couldn't Load Photo", isPresented: $showingPhotoLoadFailure) {} message: {
                Text("The selected photo couldn't be loaded. Your current cover is unchanged.")
            }
        }
    }
}

// MARK: - Toolbar & actions

extension AspirationFormView {
    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .principal) {
            coverButton
        }
        ToolbarItem(placement: .confirmationAction) {
            Button(editing == nil ? "Create" : "Save", action: save)
                .buttonStyle(.borderedProminent)
                .tint(color.prominentColor)
                .disabled(trimmedTitle.isEmpty)
        }
    }

    private var coverButton: some View {
        Menu {
            Button {
                showingPhotoPicker = true
            } label: {
                Label(imageData == nil ? "Choose Photo" : "Change Photo", systemImage: "photo")
            }
            if imageData != nil {
                Button(role: .destructive, action: removePhoto) {
                    Label("Remove Cover", systemImage: "trash")
                }
            }
        } label: {
            Label("Cover", systemImage: "photo")
        }
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
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

private struct AspirationEditorCover: View {
    let imageData: Data?
    let tint: Color

    var body: some View {
        Group {
            if let imageData, let image = AspirationCoverImages.image(from: imageData) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                LinearGradient(
                    colors: [tint, tint.opacity(0.5)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
        .frame(height: 230)
        .frame(maxWidth: .infinity)
        .clipped()
        .overlay(alignment: .bottom) {
            LinearGradient(
                colors: [.clear, Theme.screenBackground],
                startPoint: UnitPoint(x: 0.5, y: 0.55),
                endPoint: .bottom
            )
        }
    }
}

private struct AspirationEditorHeading: View {
    @Binding var title: String
    @Binding var icon: String
    let color: MetricColor
    let iconOptions: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Menu {
                Picker("Icon", selection: $icon) {
                    ForEach(iconOptions, id: \.self) { option in
                        Image(systemName: option).tag(option)
                    }
                }
            } label: {
                Image(systemName: icon)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background {
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .fill(color.prominentColor)
                    }
            }
            .accessibilityLabel("Icon")
            .accessibilityValue(icon.replacingOccurrences(of: ".", with: " "))
            VStack(alignment: .leading, spacing: 4) {
                FormEyebrow(text: "Aspiration", tint: color.color)
                TextField("Name your aspiration", text: $title, axis: .vertical)
                    .font(.largeTitle.weight(.bold))
                    .accessibilityLabel("Aspiration name")
                    .foregroundStyle(.primary)
                    .lineLimit(1 ... 3)
            }
        }
    }
}

private struct AspirationEditorWhy: View {
    @Binding var detail: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            FormEyebrow(text: "Why this matters", tint: tint)
            TextField("What makes this matter to you?", text: $detail, axis: .vertical)
                .font(.body)
                .fontDesign(.serif)
                .accessibilityLabel("Why this matters")
                .foregroundStyle(.primary)
                .lineLimit(2 ... 8)
        }
    }
}

private struct AspirationEditorColor: View {
    @Binding var color: MetricColor

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            FormEyebrow(text: "Color", tint: color.color)
            ColorSwatchRow(selection: $color)
        }
    }
}

private struct AspirationCoverImport: ViewModifier {
    @Binding var photoItem: PhotosPickerItem?
    @Binding var imageData: Data?
    @Binding var showingPhotoLoadFailure: Bool

    func body(content: Content) -> some View {
        content.onChange(of: photoItem) { _, item in
            Task { await loadPhoto(item) }
        }
    }

    /// Imports the picked cover. The stored bytes are re-encoded display
    /// pixels — the same downscale-and-JPEG pass moment photos take — never
    /// the picker's original file, so EXIF metadata (including the GPS
    /// coordinates of where the photo was taken) is stripped before anything
    /// reaches the store. A failed load keeps the existing cover and says so.
    private func loadPhoto(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        guard let raw = try? await item.loadTransferable(type: Data.self),
              let cover = MomentPhotoImport.downscaledJPEG(from: raw)
        else {
            photoItem = nil
            showingPhotoLoadFailure = true
            return
        }
        imageData = cover
    }
}
