import Foundation

/// Everything the markdown report describes, snapshotted as plain arrays so
/// the builder reads no store and tests can hand it constructed models.
struct MarkdownExportData {
    var metrics: [Metric] = []
    var aspirations: [Aspiration] = []
    var intentions: [Intention] = []
    var checkIns: [AspirationCheckIn] = []
    var moments: [Moment] = []
}

/// Renders the whole practice as one self-describing markdown artifact —
/// aspirations and metrics up front, then the chosen range week by week and
/// day by day. The file is written to be pasted into an LLM conversation;
/// that is the entire integration, deliberately: the app itself never talks
/// to a model.
enum MarkdownExporter {
    /// Writes the report to the temp file, or nil when the write fails. Any
    /// previous export at the same path is removed first, so a failed write
    /// can never hand the share sheet a stale artifact.
    static func exportFile(
        data: MarkdownExportData,
        range: ExportRange,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> URL? {
        let markdown = buildMarkdown(data: data, range: range, now: now, calendar: calendar)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(filename(range: range))
        try? FileManager.default.removeItem(at: url)
        do {
            try markdown.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }

    /// "lead-track-last-3-months.md" — the range names the artifact, so
    /// exports of different windows saved side by side stay apart.
    static func filename(range: ExportRange) -> String {
        "lead-track-\(range.fileSlug).md"
    }

    static func buildMarkdown(
        data: MarkdownExportData,
        range: ExportRange,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> String {
        let window = MarkdownExportWindow(data: data, range: range, now: now, calendar: calendar)
        var lines: [String] = []
        lines += header(range: range, now: now, calendar: calendar)
        lines += glossary
        lines += MarkdownExportProfiles.aspirations(data.aspirations)
        lines += MarkdownExportProfiles.metrics(data.metrics)
        lines += totals(of: window)
        lines += MarkdownExportWeeks.render(window)
        return lines.joined(separator: "\n")
    }
}

// MARK: - Header

extension MarkdownExporter {
    private static func header(
        range: ExportRange,
        now: Date,
        calendar: Calendar
    ) -> [String] {
        let generated = MarkdownExportDates.fullDate(now)
        let span = if let cutoff = range.cutoff(now: now, calendar: calendar) {
            "\(MarkdownExportDates.fullDate(cutoff)) – \(generated)"
        } else {
            "everything through \(generated)"
        }
        return [
            "# LeadStone — data export",
            "",
            "- Generated: \(generated)",
            "- Range: \(range.label) (\(span))",
            ""
        ]
    }
}

// MARK: - Glossary

extension MarkdownExporter {
    /// The artifact's own reading instructions — the file travels without the
    /// app, so it explains its domain language to whoever (or whatever
    /// model) reads it.
    private static let glossary: [String] = [
        "## How to read this file",
        "",
        "A plain-text export from \"LeadStone\", a personal effort-tracking app, written to be",
        "handed to an AI conversation. It opens with stable context — aspirations, then metrics —",
        "and then tells the range as a chronology: one section per calendar week, oldest first,",
        "each closing with a subsection per day.",
        "",
        "- **Aspiration** — an ongoing life theme with no target and no deadline; metrics and",
        "  projects attach to it, and effort is poured into it over a lifetime.",
        "- **Metric** — one tracked activity. Types: duration (timed), count (a number with a",
        "  unit), binary (done / not done, at most once per day).",
        "- **Project** — an optional sub-grouping inside one metric (e.g. Reading → one book).",
        "- **Session** — a single recording under a metric; day and week lines aggregate them.",
        "- **Intention** — a small commitment scoped to one calendar week under one aspiration.",
        "  Endings: done, partly, let go (released deliberately — a valid ending, not a failure),",
        "  or renewed (set again for the following week, with no verdict). Open means not yet",
        "  closed.",
        "- **Moment** — kept testimony, in the user's own words, that an aspiration is being",
        "  lived. Witnessed, never measured or counted.",
        "- **Check-in** — a weekly subjective pulse on one aspiration answering \"is this effort",
        "  still serving the why?\": serving the why / somewhere between / feels off the why.",
        "",
        "Durations read as \"1h 20m\". A binary metric's day line reads \"done\". Days and weeks",
        "with nothing recorded are omitted: a missing date means nothing was logged, not that",
        "data was lost.",
        ""
    ]
}

// MARK: - Range Totals

extension MarkdownExporter {
    private static func totals(of window: MarkdownExportWindow) -> [String] {
        var lines = ["## Totals for this range", ""]
        let tallies = MarkdownExportLines.tallies(metrics: window.metrics, sessions: window.sessions)
        if !window.metrics.isEmpty {
            lines += window.metrics.map { MarkdownExportLines.rangeLine(for: $0, among: tallies) }
            lines.append("")
        }
        lines.append(inventory(of: window))
        lines.append("")
        return lines
    }

    private static func inventory(of window: MarkdownExportWindow) -> String {
        "Moments: \(window.moments.count) · Intentions: \(window.intentions.count)"
            + " · Check-ins: \(window.checkIns.count)"
    }
}
