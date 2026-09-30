import SwiftData
import SwiftUI

/// The export sheet: pick a format and a window, share one file. Markdown is
/// the headline format — a single self-describing artifact of metrics,
/// moments, intentions, and check-ins, made for handing to an LLM chat
/// (deliberately instead of wiring a model into the app). CSV stays for
/// spreadsheets and re-import.
struct DataExportView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var format: ExportFormat = .markdown
    @State private var rangeKind: ExportRange.Kind = .last7Days
    @State private var monthCount = 3
    @State private var yearCount = 1
    @State private var scope: ExportScope = .all

    var body: some View {
        NavigationStack {
            Form {
                ExportFormatSection(format: $format)
                ExportRangeSection(kind: $rangeKind, months: $monthCount, years: $yearCount)
                if format == .csv {
                    ExportScopeSection(scope: $scope)
                }
                Section {
                    switch format {
                    case .markdown:
                        MarkdownExportLink(range: range)
                    case .csv:
                        CSVExportLink(range: range, scope: scope)
                    }
                }
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

    private var range: ExportRange {
        .make(rangeKind, months: monthCount, years: yearCount)
    }
}

private struct ExportFormatSection: View {
    @Binding var format: ExportFormat

    var body: some View {
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
            Text(footer)
        }
    }

    private var footer: String {
        switch format {
        case .markdown:
            "One self-describing file with every metric, moment, intention, and check-in, "
                + "week by week and day by day — made for handing to an AI chat."
        case .csv:
            "Raw session rows for spreadsheets, or for importing back into LeadStone."
        }
    }
}

private struct ExportRangeSection: View {
    @Binding var kind: ExportRange.Kind
    @Binding var months: Int
    @Binding var years: Int

    var body: some View {
        Section("Time Range") {
            Picker("Range", selection: $kind) {
                ForEach(ExportRange.Kind.allCases, id: \.self) { kind in
                    Text(ExportRange.make(kind, months: months, years: years).label).tag(kind)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
            if kind == .lastMonths {
                Stepper("Months: \(months)", value: $months, in: 1 ... 24)
            }
            if kind == .lastYears {
                Stepper("Years: \(years)", value: $years, in: 1 ... 20)
            }
        }
    }
}

private struct ExportScopeSection: View {
    @Query(sort: \Metric.createdAt) private var metrics: [Metric]
    @Binding var scope: ExportScope

    var body: some View {
        Section("Scope") {
            Picker("Scope", selection: $scope) {
                Text("All Metrics").tag(ExportScope.all)
                ForEach(metrics) { metric in
                    Text(metric.name)
                        .tag(ExportScope.metric(metric.persistentModelID))
                }
                ForEach(projects) { project in
                    Text("\(project.metric?.name ?? "") / \(project.name)")
                        .tag(ExportScope.project(project.persistentModelID))
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        }
    }

    private var projects: [Project] {
        metrics.flatMap(\.projects).sorted { $0.name < $1.name }
    }
}

private struct MarkdownExportLink: View {
    @Query(sort: \Metric.createdAt) private var metrics: [Metric]
    @Query(sort: \Aspiration.createdAt) private var aspirations: [Aspiration]
    @Query(sort: \Intention.createdAt) private var intentions: [Intention]
    @Query(sort: \AspirationCheckIn.createdAt) private var checkIns: [AspirationCheckIn]
    @Query(sort: \Moment.occurredAt) private var moments: [Moment]
    @Environment(\.calendar) private var calendar
    @State private var generatedAt = Date.now
    let range: ExportRange

    var body: some View {
        ExportFileLink(
            file: file,
            title: "Export Markdown Report",
            emptyMessage: "No recorded data in this range."
        )
    }

    private var file: ExportFile? {
        let data = MarkdownExportData(
            metrics: metrics, aspirations: aspirations, intentions: intentions,
            checkIns: checkIns, moments: moments
        )
        let window = MarkdownExportWindow(data: data, range: range, now: generatedAt, calendar: calendar)
        guard !window.isEmpty else { return nil }
        return ExportFile(
            contents: MarkdownExporter.buildMarkdown(
                data: data, range: range, window: window, now: generatedAt
            ),
            filename: MarkdownExporter.filename(range: range)
        )
    }
}

private struct CSVExportLink: View {
    @Query(sort: \Metric.createdAt) private var metrics: [Metric]
    @Environment(\.calendar) private var calendar
    let range: ExportRange
    let scope: ExportScope

    var body: some View {
        let sessions = filteredSessions
        ExportFileLink(
            file: sessions.isEmpty ? nil : ExportFile(
                contents: CSVExporter.buildCSV(from: sessions), filename: "lead-track-export.csv"
            ),
            title: "Export \(sessions.count) sessions",
            emptyMessage: "No sessions in this range."
        )
    }

    private var filteredSessions: [Session] {
        let completed = metrics.flatMap(\.sessions).filter { !$0.isRunning }
        let scoped = CSVExporter.filterByScope(completed, scope: scope)
        return CSVExporter.filterByTime(scoped, cutoff: range.cutoff(calendar: calendar))
            .sorted { $0.startedAt < $1.startedAt }
    }
}

/// File preparation is an effect keyed to immutable contents. A changed input
/// hides the old link immediately, so a pending/failed write cannot share it.
private struct ExportFileLink: View {
    let file: ExportFile?
    let title: String
    let emptyMessage: String
    @State private var preparedFile: ExportFile?
    @State private var url: URL?

    var body: some View {
        Group {
            if file == nil {
                note(emptyMessage)
            } else if preparedFile == file {
                if let url, let file {
                    ShareLink(item: url, preview: SharePreview(file.filename)) {
                        Label(title, systemImage: "square.and.arrow.up")
                    }
                } else {
                    note("Couldn't write the export file. Free up space and try again.")
                }
            } else {
                ProgressView()
            }
        }
        .task(id: file) {
            url = file?.write()
            preparedFile = file
        }
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}
