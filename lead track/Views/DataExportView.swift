import SwiftData
import SwiftUI

struct DataExportView: View {
    @Query(sort: \Metric.createdAt) private var metrics: [Metric]
    @Environment(\.dismiss) private var dismiss
    @State private var timeRange: ExportTimeRange = .last7Days
    @State private var scope: ExportScope = .all
    var body: some View {
        NavigationStack {
            Form {
                timeRangeSection
                scopeSection
                exportSection
            }
            .navigationTitle("Export Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Sections

extension DataExportView {
    private var timeRangeSection: some View {
        Section("Time Range") {
            Picker("Range", selection: $timeRange) {
                ForEach(
                    ExportTimeRange.allCases,
                    id: \.self
                ) { range in
                    Text(range.rawValue).tag(range)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        }
    }

    private var scopeSection: some View {
        Section("Scope") {
            Picker("Scope", selection: $scope) {
                Text("All Metrics").tag(ExportScope.all)
                ForEach(metrics) { metric in
                    Text(metric.name)
                        .tag(ExportScope.metric(metric.persistentModelID))
                }
                ForEach(allProjects) { project in
                    Text("\(project.metric?.name ?? "") / \(project.name)")
                        .tag(ExportScope.project(project.persistentModelID))
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        }
    }

    private var exportSection: some View {
        Section {
            if filteredSessions.isEmpty {
                Text("No sessions in this range.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ShareLink(
                    item: CSVExporter.exportFile(
                        from: filteredSessions
                    ),
                    preview: SharePreview("lead-track-export.csv")
                ) {
                    Label(
                        "Export \(filteredSessions.count) sessions",
                        systemImage: "square.and.arrow.up"
                    )
                }
            }
        }
    }
}

// MARK: - Data

extension DataExportView {
    private var allProjects: [Project] {
        metrics.flatMap(\.projects)
            .sorted { $0.name < $1.name }
    }

    private var filteredSessions: [Session] {
        let all = metrics.flatMap(\.sessions)
            .filter { !$0.isRunning }
        let scoped = CSVExporter.filterByScope(
            all, scope: scope
        )
        return CSVExporter.filterByTime(
            scoped,
            cutoff: CSVExporter.cutoffDate(for: timeRange)
        )
        .sorted { $0.startedAt < $1.startedAt }
    }
}
