import Foundation

/// Builds one iCalendar file containing every scheduled action for a single
/// intention. The file is a one-way snapshot for Calendar; LeadStone neither
/// requests calendar access nor attempts to mutate imported events later.
enum IntentionCalendarExporter {
    static func exportFile(
        intentionTitle: String,
        aspirationTitle: String?,
        actions: [IntentionActionDraft],
        generatedAt: Date = .now
    ) -> URL? {
        guard let calendar = buildCalendar(
            intentionTitle: intentionTitle,
            aspirationTitle: aspirationTitle,
            actions: actions,
            generatedAt: generatedAt
        ) else { return nil }
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let url = directory.appendingPathComponent(
            filename(intentionTitle: intentionTitle)
        )
        do {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
            try calendar.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            try? FileManager.default.removeItem(at: directory)
            return nil
        }
    }

    static func filename(intentionTitle: String) -> String {
        let pieces = intentionTitle.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
        let slug = String(pieces.joined(separator: "-").prefix(48))
        return "leadstone-\(slug.isEmpty ? "intention" : slug)-actions.ics"
    }

    static func buildCalendar(
        intentionTitle: String,
        aspirationTitle: String?,
        actions: [IntentionActionDraft],
        generatedAt: Date = .now
    ) -> String? {
        guard let validated = IntentionActionDraft.validated(actions),
              !validated.isEmpty
        else { return nil }
        let normalized = validated.sorted(by: calendarOrder)
        var lines = calendarHeader(intentionTitle: intentionTitle)
        for action in normalized {
            lines += eventLines(
                action,
                intentionTitle: intentionTitle,
                aspirationTitle: aspirationTitle,
                generatedAt: generatedAt
            )
        }
        lines.append("END:VCALENDAR")
        return lines.flatMap(fold).joined(separator: "\r\n") + "\r\n"
    }
}

// MARK: - Calendar Content

private extension IntentionCalendarExporter {
    static func calendarHeader(intentionTitle: String) -> [String] {
        [
            "BEGIN:VCALENDAR",
            "PRODID:-//LeadStone//Scheduled Intention Actions//EN",
            "VERSION:2.0",
            "CALSCALE:GREGORIAN",
            "X-WR-CALNAME:\(escape("LeadStone - \(intentionTitle)"))"
        ]
    }

    static func eventLines(
        _ action: IntentionActionDraft,
        intentionTitle: String,
        aspirationTitle: String?,
        generatedAt: Date
    ) -> [String] {
        let description = eventDescription(
            intentionTitle: intentionTitle,
            aspirationTitle: aspirationTitle
        )
        return [
            "BEGIN:VEVENT",
            "UID:\(action.id.uuidString.lowercased())@leadstone.app",
            "DTSTAMP:\(utcTimestamp(generatedAt))",
            "DTSTART:\(utcTimestamp(action.startsAt))",
            "DTEND:\(utcTimestamp(action.endsAt))",
            "SUMMARY:\(escape(action.trimmedTitle))",
            "DESCRIPTION:\(escape(description))",
            "STATUS:CONFIRMED",
            "TRANSP:OPAQUE",
            "END:VEVENT"
        ]
    }

    static func eventDescription(
        intentionTitle: String,
        aspirationTitle: String?
    ) -> String {
        var lines = ["Intention: \(intentionTitle)"]
        if let aspirationTitle, !aspirationTitle.isEmpty {
            lines.append("Aspiration: \(aspirationTitle)")
        }
        return lines.joined(separator: "\n")
    }

    static func calendarOrder(_ lhs: IntentionActionDraft, _ rhs: IntentionActionDraft) -> Bool {
        if lhs.startsAt != rhs.startsAt { return lhs.startsAt < rhs.startsAt }
        if lhs.endsAt != rhs.endsAt { return lhs.endsAt < rhs.endsAt }
        if lhs.title != rhs.title { return lhs.title < rhs.title }
        return lhs.id.uuidString < rhs.id.uuidString
    }
}

// MARK: - RFC 5545 Encoding

private extension IntentionCalendarExporter {
    static func utcTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        return formatter.string(from: date)
    }

    static func escape(_ text: String) -> String {
        let normalizedNewlines = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let allowedScalars = normalizedNewlines.unicodeScalars.filter { scalar in
            scalar.value == 0x09
                || scalar.value == 0x0A
                || (scalar.value >= 0x20 && scalar.value != 0x7F)
        }
        let sanitized = String(String.UnicodeScalarView(allowedScalars))
        return sanitized.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: ";", with: "\\;")
            .replacingOccurrences(of: ",", with: "\\,")
    }

    /// Content lines fold at 75 UTF-8 octets. Continuations begin with one
    /// space, and scalars stay intact so a multibyte character is never split.
    static func fold(_ line: String) -> [String] {
        var result: [String] = []
        var current = ""
        var byteCount = 0
        for scalar in line.unicodeScalars {
            let fragment = String(scalar)
            let fragmentBytes = fragment.utf8.count
            if byteCount + fragmentBytes > 75, !current.isEmpty {
                result.append(current)
                current = " "
                byteCount = 1
            }
            current += fragment
            byteCount += fragmentBytes
        }
        result.append(current)
        return result
    }
}
