import Foundation

/// One metric's share of a day, a week, or the whole range.
struct MetricTally {
    let metric: Metric
    let value: Double
    let sessionCount: Int
}

/// The report's single-line renderers, shared by the day, week, and totals
/// sections so one metric always reads the same way everywhere.
enum MarkdownExportLines {
    /// Sums sessions per metric, in the metrics' incoming order, skipping
    /// metrics the sessions never touch.
    static func tallies(metrics: [Metric], sessions: [Session]) -> [MetricTally] {
        var values: [ObjectIdentifier: Double] = [:]
        var counts: [ObjectIdentifier: Int] = [:]
        for session in sessions {
            guard let metric = session.metric else { continue }
            values[ObjectIdentifier(metric), default: 0] += session.trackingValue
            counts[ObjectIdentifier(metric), default: 0] += 1
        }
        return metrics.compactMap { metric in
            guard let value = values[ObjectIdentifier(metric)] else { return nil }
            return MetricTally(
                metric: metric,
                value: value,
                sessionCount: counts[ObjectIdentifier(metric)] ?? 0
            )
        }
    }
}

// MARK: - Metric Lines

extension MarkdownExportLines {
    /// "- Writing: 1h 10m (2 sessions)"; a binary day simply reads done.
    static func dailyLine(_ tally: MetricTally) -> String {
        guard tally.metric.measurementType.tracksQuantity else {
            return "- \(tally.metric.name): done"
        }
        var line = "- \(tally.metric.name): \(amount(of: tally))"
        if tally.sessionCount > 1 {
            line += " (\(ValueFormatter.sessions(tally.sessionCount)))"
        }
        return line
    }

    /// "- Writing: 4h 30m (6 sessions) — weekly goal 5h 00m". The goal is
    /// stated, never judged — deficit framing is not this app's language.
    static func weeklyLine(_ tally: MetricTally) -> String {
        let metric = tally.metric
        guard metric.measurementType.tracksQuantity else {
            return "- \(metric.name): \(amount(of: tally))"
        }
        var line = "- \(metric.name): \(amount(of: tally))"
        line += " (\(ValueFormatter.sessions(tally.sessionCount)))"
        if let goal = metric.weeklyGoal {
            line += " — weekly goal \(ValueFormatter.format(goal, type: metric.measurementType, unit: metric.unit))"
        }
        return line
    }

    /// The totals-section line for one metric, spelled even when the range
    /// never touched it — silence is information too.
    static func rangeLine(for metric: Metric, among tallies: [MetricTally]) -> String {
        guard let tally = tallies.first(where: { $0.metric === metric }) else {
            return "- \(metric.name): no sessions in this range"
        }
        guard metric.measurementType.tracksQuantity else {
            return "- \(metric.name): \(amount(of: tally))"
        }
        return "- \(metric.name): \(amount(of: tally)) across \(ValueFormatter.sessions(tally.sessionCount))"
    }

    private static func amount(of tally: MetricTally) -> String {
        ValueFormatter.format(
            tally.value,
            type: tally.metric.measurementType,
            unit: tally.metric.unit
        )
    }
}

// MARK: - Intention Lines

extension MarkdownExportLines {
    /// "- \"Call a friend\" (Friendship): 2 of 3 — partly". Reflective
    /// intentions carry no progress reading, deliberately.
    static func intention(_ intention: Intention, calendar: Calendar) -> String {
        var line = "- \"\(MarkdownExportText.inline(intention.title))\""
        if let aspiration = intention.aspiration {
            line += " (\(aspiration.title))"
        }
        if let progress = progressText(of: intention, calendar: calendar) {
            line += ": \(progress)"
        }
        return line + " — \(status(of: intention))"
    }

    private static func progressText(of intention: Intention, calendar: Calendar) -> String? {
        if intention.isSourceRemoved { return "source removed" }
        return IntentionProgress.compute(for: intention, calendar: calendar)?.text
    }

    /// Open, an outcome word, or — closed with no verdict — renewed.
    private static func status(of intention: Intention) -> String {
        guard !intention.isOpen else { return "open" }
        return intention.outcome?.label ?? "renewed"
    }
}

// MARK: - Check-in Lines

extension MarkdownExportLines {
    /// "- Grow wiser: Serving the why — \"note\""
    static func checkIn(_ checkIn: AspirationCheckIn) -> String {
        let title = checkIn.aspiration?.title ?? "Aspiration"
        var line = "- \(title): \(checkIn.rating?.label ?? "recorded")"
        let note = checkIn.note.trimmingCharacters(in: .whitespacesAndNewlines)
        if !note.isEmpty {
            line += " — \"\(MarkdownExportText.inline(note))\""
        }
        return line
    }
}

// MARK: - Moment Lines

extension MarkdownExportLines {
    /// "- Moment (Grow wiser): \"summit\" (during Climbing; at Mount Tam)" —
    /// the testimony verbatim, with continuation lines blockquoted inside
    /// the list item so they read as quoted material and can never forge
    /// document structure (a 2-space indent still parses as an ATX heading).
    static func moment(_ moment: Moment) -> [String] {
        var line = "- Moment"
        if let aspiration = moment.aspiration {
            line += " (\(aspiration.title))"
        }
        line += ": \"\(moment.text)\""
        if let context = context(of: moment) {
            line += " (\(context))"
        }
        return line.components(separatedBy: "\n").enumerated()
            .map { $0.offset == 0 ? $0.element : "  > \($0.element)" }
    }

    private static func context(of moment: Moment) -> String? {
        var parts: [String] = []
        if let provenance = provenance(of: moment) {
            parts.append("during \(provenance)")
        }
        if let place = moment.placeLabel {
            parts.append("at \(place)")
        }
        return parts.isEmpty ? nil : parts.joined(separator: "; ")
    }

    /// Where it happened: "Writing / Novel draft", either half optional.
    private static func provenance(of moment: Moment) -> String? {
        switch (moment.metric, moment.project) {
        case let (metric?, project?): "\(metric.name) / \(project.name)"
        case let (metric?, nil): metric.name
        case let (nil, project?): project.name
        case (nil, nil): nil
        }
    }
}
