import SwiftData
import SwiftUI
import UIKit

/// A focused Moment composer presented directly by the Photos share sheet.
/// Photos has no aspiration context, so this capture path asks for its owning why.
struct ShareMomentView: View {
    let extensionContext: NSExtensionContext
    @State private var loader: SharePhotoLoader?

    var body: some View {
        Group {
            if let loader {
                ShareMomentComposer(loader: loader)
            } else {
                ProgressView("Importing photos…")
            }
        }
        .task {
            // State owns one loader for the request; parent view construction
            // never creates a loader or starts provider work.
            if loader == nil {
                loader = SharePhotoLoader(extensionContext: extensionContext)
            }
        }
    }
}

private struct ShareMomentComposer: View {
    @Environment(\.modelContext) private var modelContext
    let loader: SharePhotoLoader
    @State private var selectedAspiration: Aspiration?
    @State private var text = ""
    @State private var occurredAt = Date.now
    @State private var isSaving = false
    @State private var saveError: String?

    var body: some View {
        NavigationStack {
            Form {
                ShareAspirationSection(selection: $selectedAspiration)
                Section("Moment") {
                    TextField("What grew out of this?", text: $text, axis: .vertical)
                        .lineLimit(3 ... 8)
                }
                Section("When") {
                    DatePicker(
                        "When it happened",
                        selection: $occurredAt,
                        in: ...Date.now,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                }
                SharePhotosSection(loader: loader)
            }
            .navigationTitle("Keep a Moment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            .task { await loader.load() }
            .alert("Moment Couldn't Be Kept", isPresented: errorPresented) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(saveError ?? "The shared library couldn't be updated.")
            }
        }
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
        selectedAspiration?.isArchived == false
            && !trimmedText.isEmpty
            && loader.state == .loaded
            && !isSaving
    }

    private var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var errorPresented: Binding<Bool> {
        Binding(
            get: { saveError != nil },
            set: { presented in if !presented { saveError = nil } }
        )
    }

    private func save() {
        guard canSave, let selectedAspiration else { return }
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

private struct ShareAspirationSection: View {
    @Query(sort: \Aspiration.createdAt) private var aspirations: [Aspiration]
    @Binding var selection: Aspiration?

    var body: some View {
        let choices = aspirations.unarchived.inDisplayOrder
        Section {
            if choices.isEmpty {
                Text("Create or bring back an aspiration in LeadStone before keeping a moment.")
                    .foregroundStyle(.secondary)
            } else {
                Picker("Aspiration", selection: $selection) {
                    Text("Choose an aspiration").tag(Aspiration?.none)
                    ForEach(choices) { aspiration in
                        Text(aspiration.title).tag(Aspiration?.some(aspiration))
                    }
                }
            }
        } header: {
            Text("Belongs to")
        }
        .task {
            if choices.count == 1 {
                selection = choices.first
            }
        }
        .onChange(of: selection?.isArchived) { _, archived in
            if archived == true { selection = nil }
        }
    }
}

private struct SharePhotosSection: View {
    let loader: SharePhotoLoader

    var body: some View {
        Section {
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
                ScrollView(.horizontal) {
                    HStack(spacing: 10) {
                        ForEach(loader.photos) { photo in
                            SharePhotoThumbnail(photo: photo, loader: loader)
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
        } header: {
            Text("Photos")
        } footer: {
            if loader.failureCount > 0 {
                Text(loader.failureCount == 1
                    ? "One photo couldn't be imported."
                    : "\(loader.failureCount.formatted()) photos couldn't be imported.")
            }
        }
    }
}

private struct SharePhotoThumbnail: View {
    let photo: SharePhoto
    let loader: SharePhotoLoader

    var body: some View {
        if let image = UIImage(data: photo.data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 84, height: 84)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Theme.photoOutline, lineWidth: 1)
                }
                .overlay(alignment: .topTrailing) {
                    Button {
                        loader.remove(photo)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.white, .black.opacity(0.55))
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(5)
                    .accessibilityLabel("Remove photo")
                }
        }
    }
}
