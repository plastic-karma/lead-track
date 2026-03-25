import SwiftData
import SwiftUI

struct MetricFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var icon = "clock"

    private let iconOptions = [
        "clock", "book", "laptopcomputer",
        "figure.run", "pencil", "music.note",
        "paintbrush", "hammer", "gamecontroller"
    ]

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                iconPicker
            }
            .navigationTitle("New Metric")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(name.isEmpty)
                }
            }
        }
    }

    private var iconPicker: some View {
        Section("Icon") {
            iconGrid
        }
    }

    private var iconGrid: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 44))],
            spacing: 12
        ) {
            ForEach(iconOptions, id: \.self) { option in
                iconButton(option)
            }
        }
    }

    private func iconButton(_ option: String) -> some View {
        Button {
            icon = option
        } label: {
            Image(systemName: option)
                .font(.title2)
                .frame(width: 44, height: 44)
                .background(
                    icon == option
                        ? Color.accentColor.opacity(0.2)
                        : Color.clear
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private func save() {
        let metric = Metric(name: name, icon: icon)
        modelContext.insert(metric)
        dismiss()
    }
}
