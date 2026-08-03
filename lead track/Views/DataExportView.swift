import SwiftData
import SwiftUI

/// The export sheet: pick a format and a window, share one file. Markdown is
/// the headline format — a single self-describing artifact of metrics,
/// moments, intentions with scheduled actions, and check-ins, made for handing
/// to an LLM chat (deliberately instead of wiring a model into the app). CSV
/// stays for spreadsheets and re-import.
struct DataExportView: View {
    @Query(sort: \Metric.createdAt) private var metrics: [Metric]
    @Query(sort: \Aspiration.createdAt) private var aspirations: [Aspiration]
    @Query(sort: \Intention.createdAt) private var intentions: [Intention]
    @Query(sort: \IntentionAction.startsAt) private var actions: [IntentionAction]
    @Query(sort: \AspirationCheckIn.createdAt) private var checkIns: [AspirationCheckIn]
    @Query(sort: \Moment.occurredAt) private var moments: [Moment]
    @Environment(\.dismiss) private var dismiss
    @State private var format: ExportFormat = .markdown
    @State private var rangeKind: ExportRange.Kind = .last7Days
    @State private var monthCount = 3
    @State private var yearCount = 1
    @State private var scope: ExportScope = .all

    var body: some View {
        NavigationStack {
            Form {
                formatSection
                timeRangeSection
                if format == .csv {
                    scopeSection
                }
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

// MARK: - Format & Range Sections

extension DataExportView {
    private var formatSection: some View {
        Section {
            Picker("Format", selection: $format) {
                ForEach(ExportFormat.allCases, id: \.self) { format in
                    Text(format.rawValue).tag(format)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        } header: {
            Text("Format")
        } footer: {
            Text(formatFooter)
        }
    }

    private var formatFooter: String {
        switch format {
        case .markdown:
            "One self-describing file with every metric, moment, intention, scheduled action, and check-in, "
                + "week by week and day by day — made for handing to an AI chat."
        case .csv:
            "Raw session rows for spreadsheets, or for importing back into LeadStone."
        }
    }

    private var timeRangeSection: some View {
        Section("Time Range") {
            Picker("Range", selection: $rangeKind) {
                ForEach(ExportRange.Kind.allCases, id: \.self) { kind in
                    Text(range(for: kind).label).tag(kind)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
            if rangeKind == .lastMonths {
                Stepper("Months: \(monthCount)", value: $monthCount, in: 1 ... 24)
            }
            if rangeKind == .lastYears {
                Stepper("Years: \(yearCount)", value: $yearCount, in: 1 ... 20)
            }
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
}

// MARK: - Export Section

extension DataExportView {
    private var exportSection: some View {
        Section {
            switch format {
            case .markdown: markdownLink
            case .csv: csvLink
            }
        }
    }

    @ViewBuilder private var markdownLink: some View {
        if markdownWindow.isEmpty {
            emptyNote("No recorded data in this range.")
        } else if let url = MarkdownExporter.exportFile(data: exportData, range: range) {
            ShareLink(
                item: url,
                preview: SharePreview(MarkdownExporter.filename(range: range))
            ) {
                Label("Export Markdown Report", systemImage: "square.and.arrow.up")
            }
        } else {
            emptyNote("Couldn't write the export file. Free up space and try again.")
        }
    }

    @ViewBuilder private var csvLink: some View {
        if filteredSessions.isEmpty {
            emptyNote("No sessions in this range.")
        } else if let url = CSVExporter.exportFile(from: filteredSessions) {
            ShareLink(
                item: url,
                preview: SharePreview("lead-track-export.csv")
            ) {
                Label(
                    "Export \(filteredSessions.count) sessions",
                    systemImage: "square.and.arrow.up"
                )
            }
        } else {
            emptyNote("Couldn't write the export file. Free up space and try again.")
        }
    }

    private func emptyNote(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}

// MARK: - Data

extension DataExportView {
    private var range: ExportRange {
        range(for: rangeKind)
    }

    private func range(for kind: ExportRange.Kind) -> ExportRange {
        .make(kind, months: monthCount, years: yearCount)
    }

    private var exportData: MarkdownExportData {
        MarkdownExportData(
            metrics: metrics,
            aspirations: aspirations,
            intentions: intentions,
            actions: actions,
            checkIns: checkIns,
            moments: moments
        )
    }

    private var markdownWindow: MarkdownExportWindow {
        MarkdownExportWindow(data: exportData, range: range)
    }

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
            scoped, cutoff: range.cutoff()
        )
        .sorted { $0.startedAt < $1.startedAt }
    }
}
