import Foundation

/// The chronological body of the report: one `##` section per populated
/// week, oldest first — totals, intentions, and check-ins up front, then a
/// `###` subsection per populated day.
enum MarkdownExportWeeks {
    static func render(_ window: MarkdownExportWindow) -> [String] {
        guard !window.weeks.isEmpty else {
            return ["No recorded data in this range.", ""]
        }
        return window.weeks.flatMap { lines(for: $0, in: window) }
    }
}

// MARK: - One Week

extension MarkdownExportWeeks {
    private static func lines(
        for week: MarkdownExportWeek,
        in window: MarkdownExportWindow
    ) -> [String] {
        let heading = MarkdownExportDates.weekRange(week.interval, calendar: window.calendar)
        var lines = ["## Week of \(heading)", ""]
        lines += totalLines(of: week, in: window)
        lines += intentionLines(of: week, calendar: window.calendar)
        lines += checkInLines(of: week)
        lines += week.days.flatMap { dayLines(for: $0, in: window) }
        return lines
    }

    private static func totalLines(
        of week: MarkdownExportWeek,
        in window: MarkdownExportWindow
    ) -> [String] {
        let tallies = MarkdownExportLines.tallies(metrics: window.metrics, sessions: week.sessions)
        guard !tallies.isEmpty else { return [] }
        return ["**Week totals**", ""] + tallies.map(MarkdownExportLines.weeklyLine) + [""]
    }

    private static func intentionLines(of week: MarkdownExportWeek, calendar: Calendar) -> [String] {
        guard !week.intentions.isEmpty else { return [] }
        let lines = week.intentions.flatMap { intention in
            var lines = [MarkdownExportLines.intention(intention, calendar: calendar)]
            guard let intentionID = intention.stableID else { return lines }
            lines += week.actions
                .filter { $0.intentionID == intentionID }
                .map(MarkdownExportLines.scheduledAction)
            return lines
        }
        return ["**Intentions**", ""] + lines + [""]
    }

    private static func checkInLines(of week: MarkdownExportWeek) -> [String] {
        guard !week.checkIns.isEmpty else { return [] }
        return ["**Check-ins**", ""] + week.checkIns.map(MarkdownExportLines.checkIn) + [""]
    }
}

// MARK: - One Day

extension MarkdownExportWeeks {
    private static func dayLines(
        for day: MarkdownExportDay,
        in window: MarkdownExportWindow
    ) -> [String] {
        var lines = ["### \(MarkdownExportDates.dayHeading(day.day))", ""]
        let tallies = MarkdownExportLines.tallies(metrics: window.metrics, sessions: day.sessions)
        lines += tallies.map(MarkdownExportLines.dailyLine)
        lines += day.moments.flatMap(MarkdownExportLines.moment)
        lines.append("")
        return lines
    }
}

// MARK: - Dates

/// The report's date spellings. Every formatter is pinned to en_US_POSIX:
/// the artifact is written for a language model, so it favors one stable,
/// unambiguous spelling over the device locale.
enum MarkdownExportDates {
    private static let posix = Locale(identifier: "en_US_POSIX")

    /// "July 9, 2026"
    static func fullDate(_ date: Date) -> String {
        date.formatted(.dateTime.month(.wide).day().year().locale(posix))
    }

    /// "Aug 4, 2026 at 9:00 AM" in the user's current time zone.
    static func dateTime(_ date: Date) -> String {
        date.formatted(
            .dateTime.month(.abbreviated).day().year().hour().minute().locale(posix)
        )
    }

    /// "Monday, June 30, 2026"
    static func dayHeading(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.wide).month(.wide).day().year().locale(posix))
    }

    /// "June 2024"
    static func monthYear(_ date: Date) -> String {
        date.formatted(.dateTime.month(.wide).year().locale(posix))
    }

    /// "June 30 – July 6, 2026", spelling both years out when the week
    /// crosses a year boundary.
    static func weekRange(_ interval: DateInterval, calendar: Calendar = .current) -> String {
        let lastDay = calendar.date(byAdding: .day, value: -1, to: interval.end) ?? interval.start
        guard calendar.isDate(interval.start, equalTo: lastDay, toGranularity: .year) else {
            return "\(fullDate(interval.start)) – \(fullDate(lastDay))"
        }
        let start = interval.start.formatted(.dateTime.month(.wide).day().locale(posix))
        return "\(start) – \(fullDate(lastDay))"
    }
}
