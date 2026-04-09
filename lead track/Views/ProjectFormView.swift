import SwiftData
import SwiftUI

struct ProjectFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let metric: Metric
    @State private var name = ""

    private var nameIsDuplicate: Bool {
        metric.projects.contains {
            $0.name.lowercased() == name.lowercased()
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Project Name", text: $name)
                    if nameIsDuplicate {
                        Text("A project with this name already exists.")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("New Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(name.isEmpty || nameIsDuplicate)
                }
            }
        }
    }

    private func save() {
        let project = Project(name: name, metric: metric)
        modelContext.insert(project)
        dismiss()
    }
}
