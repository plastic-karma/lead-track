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
    @State private var saveTrigger = false

    private let iconOptions = [
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
            editor
        }
    }

    private var editor: some View {
        ZStack {
            Theme.screenBackground.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    cover
                    content
                }
            }
            .scrollIndicators(.hidden)
            .ignoresSafeArea(edges: .top)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbar }
        .toolbarBackground(.hidden, for: .navigationBar)
        .photosPicker(isPresented: $showingPhotoPicker, selection: $photoItem, matching: .images)
        .sensoryFeedback(.success, trigger: saveTrigger)
        .onChange(of: photoItem) { _, item in
            Task { await loadPhoto(item) }
        }
    }
}

// MARK: - Layout

extension AspirationFormView {
    private var content: some View {
        VStack(alignment: .leading, spacing: 28) {
            headerBlock
            whySection
            colorSection
            AspirationFeedPicker(
                selectedMetrics: $selectedMetrics,
                selectedProjects: $selectedProjects,
                tint: color.color,
                prominentTint: color.prominentColor
            )
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 40)
    }

    private var cover: some View {
        coverBackground
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

    @ViewBuilder
    private var coverBackground: some View {
        if let image = currentCover {
            image.resizable().scaledToFill()
        } else {
            LinearGradient(
                colors: [color.color, color.color.opacity(0.5)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var headerBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            iconBadge
            VStack(alignment: .leading, spacing: 4) {
                FormEyebrow(text: "Aspiration", tint: color.color)
                TextField("Name your aspiration", text: $title, axis: .vertical)
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1 ... 3)
            }
        }
    }

    private var iconBadge: some View {
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
                .background(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(color.prominentColor)
                )
        }
        .accessibilityLabel("Icon")
        .accessibilityValue(icon.replacingOccurrences(of: ".", with: " "))
    }

    private var whySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            FormEyebrow(text: "Why this matters", tint: color.color)
            TextField("What makes this matter to you?", text: $detail, axis: .vertical)
                .font(.body)
                .foregroundStyle(.primary)
                .lineLimit(2 ... 8)
        }
    }

    private var colorSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            FormEyebrow(text: "Color", tint: color.color)
            ColorSwatchRow(selection: $color)
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
