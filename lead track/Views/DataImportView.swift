import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct DataImportView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Metric.createdAt) private var metrics: [Metric]
    @State private var showingPicker = false
    @State private var summary: CSVImporter.ImportSummary?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                introSection
                actionSection
                if let summary {
                    summarySection(summary)
                }
                if let errorMessage {
                    errorSection(errorMessage)
                }
            }
            .navigationTitle("Import Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .fileImporter(
                isPresented: $showingPicker,
                allowedContentTypes: [.commaSeparatedText],
                allowsMultipleSelection: false,
                onCompletion: handleSelection
            )
        }
    }
}

// MARK: - Sections

extension DataImportView {
    private var introSection: some View {
        Section {
            Text(
                "Import sessions from a CSV file produced by "
                    + "lead-track export. Missing metrics or projects "
                    + "will be created automatically."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private var actionSection: some View {
        Section {
            Button {
                summary = nil
                errorMessage = nil
                showingPicker = true
            } label: {
                Label("Choose CSV File", systemImage: "square.and.arrow.down")
            }
        }
    }

    private func summarySection(
        _ summary: CSVImporter.ImportSummary
    ) -> some View {
        Section("Imported") {
            row("Sessions created", summary.sessionsCreated)
            row("Metrics created", summary.metricsCreated)
            row("Projects created", summary.projectsCreated)
            if summary.rowsSkipped > 0 {
                row("Rows skipped", summary.rowsSkipped)
            }
        }
    }

    private func errorSection(_ message: String) -> some View {
        Section {
            Label(message, systemImage: "exclamationmark.triangle")
                .foregroundStyle(.red)
        }
    }

    private func row(_ label: String, _ value: Int) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text("\(value)").foregroundStyle(.secondary)
        }
    }
}

// MARK: - Import

extension DataImportView {
    private func handleSelection(
        _ result: Result<[URL], Error>
    ) {
        switch result {
        case let .success(urls):
            guard let url = urls.first else { return }
            performImport(from: url)
        case let .failure(error):
            errorMessage = error.localizedDescription
        }
    }

    private func performImport(from url: URL) {
        let needsScope = url.startAccessingSecurityScopedResource()
        defer {
            if needsScope { url.stopAccessingSecurityScopedResource() }
        }
        do {
            let contents = try String(contentsOf: url, encoding: .utf8)
            summary = try CSVImporter.importCSV(
                contents: contents,
                existingMetrics: metrics,
                context: modelContext
            )
            errorMessage = nil
        } catch {
            summary = nil
            errorMessage = error.localizedDescription
        }
    }
}
