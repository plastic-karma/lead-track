import SwiftData
import SwiftUI
import UIKit

/// A focused Moment composer presented directly by the Photos share sheet.
/// Photos has no aspiration context, so this one capture path asks for the
/// owning why before it can keep the testimony.
struct ShareMomentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Aspiration.createdAt) private var aspirations: [Aspiration]
    @StateObject private var loader: SharePhotoLoader

    @State private var selectedAspiration: Aspiration?
    @State private var text = ""
    @State private var occurredAt = Date.now
    @State private var isSaving = false
    @State private var saveError: String?

    init(extensionContext: NSExtensionContext) {
        _loader = StateObject(
            wrappedValue: SharePhotoLoader(extensionContext: extensionContext)
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                aspirationSection
                momentSection
                whenSection
                photosSection
            }
            .navigationTitle("Keep a Moment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            .task {
                selectOnlyAspiration()
                await loader.load()
            }
            .alert("Moment Couldn't Be Kept", isPresented: errorPresented) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(saveError ?? "The shared library couldn't be updated.")
            }
        }
    }

    private var aspirationSection: some View {
        Section {
            if aspirations.isEmpty {
                Text("Create an aspiration in LeadStone before keeping a moment.")
                    .foregroundStyle(.secondary)
            } else {
                Picker("Aspiration", selection: $selectedAspiration) {
                    Text("Choose an aspiration").tag(Aspiration?.none)
                    ForEach(aspirations) { aspiration in
                        Text(aspiration.title).tag(Aspiration?.some(aspiration))
                    }
                }
            }
        } header: {
            Text("Belongs to")
        }
    }

    private var momentSection: some View {
        Section("Moment") {
            TextField("What grew out of this?", text: $text, axis: .vertical)
                .lineLimit(3 ... 8)
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

    private var photosSection: some View {
        Section {
            photoContent
        } header: {
            Text("Photos")
        } footer: {
            if loader.failureCount > 0 {
                Text(importFailureNote)
            }
        }
    }

    @ViewBuilder
    private var photoContent: some View {
        switch loader.state {
        case .idle, .loading:
            HStack {
                ProgressView()
                Text("Importing photos…")
                    .foregroundStyle(.secondary)
            }
        case .loaded where loader.photos.isEmpty:
            Label("No photos could be imported", systemImage: "exclamationmark.triangle")
                .foregroundStyle(.secondary)
        case .loaded:
            photoStrip
        }
    }

    private var photoStrip: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 10) {
                ForEach(loader.photos) { photo in
                    thumbnail(photo)
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    @ViewBuilder
    private func thumbnail(_ photo: SharePhoto) -> some View {
        if let image = UIImage(data: photo.data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 84, height: 84)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(alignment: .topTrailing) {
                    removeButton(photo)
                }
        }
    }

    private func removeButton(_ photo: SharePhoto) -> some View {
        Button {
            loader.remove(photo)
        } label: {
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.white, .black.opacity(0.55))
        }
        .padding(5)
        .accessibilityLabel("Remove photo")
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel", action: loader.cancel)
                .disabled(isSaving)
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("Keep", action: save)
                .disabled(!canSave)
        }
    }

    private var canSave: Bool {
        selectedAspiration != nil
            && !trimmedText.isEmpty
            && loader.state == .loaded
            && !isSaving
    }

    private var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var importFailureNote: String {
        loader.failureCount == 1
            ? "One photo couldn't be imported."
            : "\(loader.failureCount) photos couldn't be imported."
    }

    private var errorPresented: Binding<Bool> {
        Binding(
            get: { saveError != nil },
            set: { presented in if !presented { saveError = nil } }
        )
    }

    private func selectOnlyAspiration() {
        if aspirations.count == 1 {
            selectedAspiration = aspirations.first
        }
    }

    private func save() {
        guard let selectedAspiration else { return }
        isSaving = true
        let moment = Moment(
            text: trimmedText,
            aspiration: selectedAspiration,
            occurredAt: min(occurredAt, .now)
        )
        modelContext.insert(moment)
        MomentPhotoReconciler.sync(loader.photos.map(\.data), with: moment, in: modelContext)
        save(moment)
    }

    private func save(_ moment: Moment) {
        do {
            try modelContext.save()
            loader.finish()
        } catch {
            modelContext.delete(moment)
            modelContext.rollback()
            saveError = error.localizedDescription
            isSaving = false
        }
    }
}
