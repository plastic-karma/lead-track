import Foundation

/// The report's stable-context sections: who the aspirations are and what
/// the metrics measure, rendered once ahead of the week-by-week chronology
/// so every later line has something to refer back to.
enum MarkdownExportProfiles {
    static func aspirations(_ aspirations: [Aspiration]) -> [String] {
        guard !aspirations.isEmpty else { return [] }
        return ["## Aspirations", ""] + aspirations.flatMap(profile(of:))
    }

    static func metrics(_ metrics: [Metric]) -> [String] {
        guard !metrics.isEmpty else { return [] }
        return ["## Metrics", ""] + metrics.flatMap(profile(of:))
    }
}

// MARK: - Aspiration

extension MarkdownExportProfiles {
    private static func profile(of aspiration: Aspiration) -> [String] {
        var lines = ["### \(MarkdownExportText.inline(aspiration.title))", ""]
        let detail = aspiration.detail.trimmingCharacters(in: .whitespacesAndNewlines)
        if !detail.isEmpty {
            lines += MarkdownExportText.quoted(detail)
            lines.append("")
        }
        lines += attachments(of: aspiration)
        lines.append("")
        return lines
    }

    private static func attachments(of aspiration: Aspiration) -> [String] {
        var lines: [String] = []
        if !aspiration.metrics.isEmpty {
            lines.append("- Attached metrics: \(aspiration.metrics.map(\.name).joined(separator: ", "))")
        }
        if !aspiration.projects.isEmpty {
            let projects = aspiration.projects.map(projectReference).joined(separator: ", ")
            lines.append("- Attached projects: \(projects)")
        }
        if lines.isEmpty {
            lines.append("- No metrics or projects attached yet.")
        }
        return lines
    }

    private static func projectReference(_ project: Project) -> String {
        guard let metric = project.metric else { return project.name }
        return "\(project.name) (under \(metric.name))"
    }
}

// MARK: - Metric

extension MarkdownExportProfiles {
    private static func profile(of metric: Metric) -> [String] {
        var lines = ["### \(MarkdownExportText.inline(metric.name)) (\(typeLabel(metric)))", ""]
        if let description = metric.metricDescription {
            lines += MarkdownExportText.quoted(description)
            lines.append("")
        }
        lines += facts(of: metric)
        lines.append("")
        return lines
    }

    private static func facts(of metric: Metric) -> [String] {
        var lines = ["- Tracked since: \(MarkdownExportDates.monthYear(metric.createdAt))"]
        lines += goalLines(of: metric)
        if let source = metric.healthSource {
            lines.append("- Mirrored from Apple Health: \(source.displayName)")
        }
        if !metric.projects.isEmpty {
            let projects = metric.projects.map { "\($0.name) (\($0.status.rawValue))" }
            lines.append("- Projects: \(projects.joined(separator: ", "))")
        }
        return lines
    }

    private static func goalLines(of metric: Metric) -> [String] {
        guard metric.measurementType.tracksQuantity else { return [] }
        var lines: [String] = []
        if let daily = metric.dailyGoal {
            lines.append("- Daily goal: \(format(daily, of: metric))")
        }
        if let weekly = metric.weeklyGoal {
            lines.append("- Weekly goal: \(format(weekly, of: metric))")
        }
        return lines
    }

    private static func typeLabel(_ metric: Metric) -> String {
        switch metric.measurementType {
        case .duration:
            return "duration"
        case .count:
            guard let unit = metric.unit, !unit.isEmpty else { return "count" }
            return "count, unit: \(unit)"
        case .binary:
            return "binary"
        }
    }

    private static func format(_ value: Double, of metric: Metric) -> String {
        ValueFormatter.format(value, type: metric.measurementType, unit: metric.unit)
    }
}
