import SwiftData
import SwiftUI

enum ExportTimeRange: String, CaseIterable {
    case last7Days = "Last 7 Days"
    case lastMonth = "Last Month"
    case yearToDate = "Year to Date"
    case lastYear = "Last Year"
    case all = "All Time"
}

enum ExportScope: Hashable {
    case all
    case metric(PersistentIdentifier)
    case project(PersistentIdentifier)
}

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
                    item: exportFile(),
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

    private var cutoffDate: Date? {
        let cal = Calendar.current
        let now = Date.now
        switch timeRange {
        case .last7Days:
            return cal.date(byAdding: .day, value: -6, to: cal.startOfDay(for: now))
        case .lastMonth:
            return cal.date(byAdding: .month, value: -1, to: now)
        case .yearToDate:
            return cal.date(from: cal.dateComponents([.year], from: now))
        case .lastYear:
            return cal.date(byAdding: .year, value: -1, to: now)
        case .all:
            return nil
        }
    }

    private var filteredSessions: [Session] {
        let all = metrics.flatMap(\.sessions)
            .filter { !$0.isRunning }
        let scoped = filterByScope(all)
        return filterByTime(scoped)
            .sorted { $0.startedAt < $1.startedAt }
    }

    private func filterByScope(
        _ sessions: [Session]
    ) -> [Session] {
        switch scope {
        case .all:
            return sessions
        case let .metric(id):
            return sessions.filter {
                $0.metric?.persistentModelID == id
            }
        case let .project(id):
            return sessions.filter {
                $0.project?.persistentModelID == id
            }
        }
    }

    private func filterByTime(
        _ sessions: [Session]
    ) -> [Session] {
        guard let cutoff = cutoffDate else { return sessions }
        return sessions.filter { $0.startedAt >= cutoff }
    }
}

// MARK: - Export

extension DataExportView {
    private func exportFile() -> URL {
        let csv = buildCSV()
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("lead-track-export.csv")
        try? csv.write(
            to: url, atomically: true, encoding: .utf8
        )
        return url
    }

    private func buildCSV() -> String {
        var lines = [csvHeader]
        for session in filteredSessions {
            lines.append(csvRow(session))
        }
        return lines.joined(separator: "\n")
    }

    private var csvHeader: String {
        "Metric,Project,Date,Start,End,Duration (s),Value,Type"
    }

    private func csvRow(_ session: Session) -> String {
        let metric = escape(session.metric?.name ?? "")
        let project = escape(session.project?.name ?? "")
        let date = session.startedAt.formatted(date: .numeric, time: .omitted)
        let start = session.startedAt.formatted(date: .omitted, time: .standard)
        let end = session.endedAt?.formatted(date: .omitted, time: .standard) ?? ""
        let duration = String(format: "%.0f", session.duration)
        let value = session.value.map { String(format: "%.1f", $0) } ?? ""
        let type = session.metric?.measurementType.rawValue ?? "duration"
        return "\(metric),\(project),\(date),\(start),\(end),\(duration),\(value),\(type)"
    }

    private func escape(_ text: String) -> String {
        if text.contains(",") || text.contains("\"") || text.contains("\n") {
            return "\"\(text.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return text
    }
}
