import Foundation
import Testing
@testable import lead_track

struct IntentionCalendarExporterTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? calendar.timeZone
        return calendar
    }

    private func date(
        _ day: Int,
        _ hour: Int = 0,
        _ minute: Int = 0,
        _ second: Int = 0
    ) -> Date {
        let components = DateComponents(
            year: 2026,
            month: 8,
            day: day,
            hour: hour,
            minute: minute,
            second: second
        )
        guard let date = calendar.date(from: components) else {
            preconditionFailure("Invalid fixed test date")
        }
        return date
    }

    private func action(
        id: UUID = UUID(),
        title: String = "Write",
        startsAt: Date? = nil,
        endsAt: Date? = nil
    ) -> IntentionActionDraft {
        IntentionActionDraft(
            id: id,
            title: title,
            startsAt: startsAt ?? date(4, 9),
            endsAt: endsAt ?? date(4, 9, 30)
        )
    }

    private func build(_ actions: [IntentionActionDraft]) -> String? {
        IntentionCalendarExporter.buildCalendar(
            intentionTitle: "Write with courage",
            aspirationTitle: "Creative life",
            actions: actions,
            generatedAt: date(2, 12, 34, 56)
        )
    }
}

// MARK: - Calendar Contract

extension IntentionCalendarExporterTests {
    @Test
    func emptyOrInvalidActionsProduceNoCalendar() {
        #expect(build([]) == nil)
        #expect(build([action(title: "  ")]) == nil)
        #expect(build([action(startsAt: date(4, 10), endsAt: date(4, 9))]) == nil)
        #expect(build([action(startsAt: date(4, 10), endsAt: date(4, 10, 14))]) == nil)
    }

    @Test
    func invalidOrDuplicateRowsRejectTheWholeCalendar() {
        let id = UUID()
        let valid = action(id: id)
        #expect(build([valid, action(title: "  ")]) == nil)
        #expect(build([valid, action(id: id, title: "Duplicate")]) == nil)
    }

    @Test
    func oneActionBecomesOneStableUtcEvent() throws {
        let id = try #require(UUID(
            uuidString: "12345678-1234-1234-1234-123456789ABC"
        ))
        let ics = try #require(build([action(id: id)]))

        #expect(ics.contains("BEGIN:VCALENDAR\r\n"))
        #expect(ics.contains("VERSION:2.0\r\n"))
        #expect(!ics.contains("METHOD:"))
        #expect(ics.contains("UID:12345678-1234-1234-1234-123456789abc@leadstone.app\r\n"))
        #expect(ics.contains("DTSTAMP:20260802T123456Z\r\n"))
        #expect(ics.contains("DTSTART:20260804T090000Z\r\n"))
        #expect(ics.contains("DTEND:20260804T093000Z\r\n"))
        #expect(ics.components(separatedBy: "BEGIN:VEVENT").count - 1 == 1)
        #expect(ics.hasSuffix("END:VCALENDAR\r\n"))
    }

    @Test
    func userTextIsEscapedForICalendar() throws {
        let title = "Plan, pray; reflect\\again\nsoon"
        let ics = try #require(build([action(title: title)]))
        let unfolded = ics.replacingOccurrences(of: "\r\n ", with: "")

        #expect(unfolded.contains("SUMMARY:Plan\\, pray\\; reflect\\\\again\\nsoon\r\n"))
        #expect(unfolded.contains(
            "DESCRIPTION:Intention: Write with courage\\nAspiration: Creative life\r\n"
        ))
    }

    @Test
    func propertyInjectionAndControlCharactersAreRemoved() throws {
        let title = "First\r\nATTENDEE:bad\u{0}\u{7F}\tlast"
        let ics = try #require(build([action(title: title)]))
        let unfolded = ics.replacingOccurrences(of: "\r\n ", with: "")

        #expect(!unfolded.contains("\r\nATTENDEE:"))
        #expect(unfolded.contains("SUMMARY:First\\nATTENDEE:bad\tlast\r\n"))
        #expect(!unfolded.contains("\u{0}"))
        #expect(!unfolded.contains("\u{7F}"))
    }

    @Test
    func eventsSortByStartRegardlessOfDraftOrder() throws {
        let later = action(title: "Later", startsAt: date(5, 15), endsAt: date(5, 16))
        let earlier = action(title: "Earlier", startsAt: date(4, 9), endsAt: date(4, 10))
        let ics = try #require(build([later, earlier]))
        let earlierRange = try #require(ics.range(of: "SUMMARY:Earlier"))
        let laterRange = try #require(ics.range(of: "SUMMARY:Later"))

        #expect(earlierRange.lowerBound < laterRange.lowerBound)
    }

    @Test
    func everyPhysicalLineFitsTheSeventyFiveOctetLimit() throws {
        let title = String(repeating: "Café reflection 🌱 ", count: 11)
            + "Café reflection 🌱"
        let ics = try #require(build([action(title: title)]))
        let lines = ics.components(separatedBy: "\r\n").dropLast()

        #expect(lines.allSatisfy { $0.utf8.count <= 75 })
        #expect(lines.contains { $0.hasPrefix(" ") })
        let unfolded = ics.replacingOccurrences(of: "\r\n ", with: "")
        #expect(unfolded.contains("SUMMARY:\(title)"))
    }

    @Test
    func calendarUsesOnlyCrLfLineEndings() throws {
        let ics = try #require(build([action()]))
        let withoutCrLf = ics.replacingOccurrences(of: "\r\n", with: "")
        #expect(!withoutCrLf.contains("\n"))
        #expect(!withoutCrLf.contains("\r"))
    }
}

// MARK: - File Handoff

extension IntentionCalendarExporterTests {
    @Test
    func filenameIsSafeAndFallsBackForSymbols() {
        #expect(
            IntentionCalendarExporter.filename(intentionTitle: "Write / Reflect, Daily")
                == "leadstone-write-reflect-daily-actions.ics"
        )
        #expect(
            IntentionCalendarExporter.filename(intentionTitle: "🌱")
                == "leadstone-intention-actions.ics"
        )
    }

    @Test
    func exportsAreImmutableAndIsolatedEvenWhenSlugsCollide() throws {
        let firstURL = try #require(IntentionCalendarExporter.exportFile(
            intentionTitle: "Write with courage",
            aspirationTitle: nil,
            actions: [action(title: "First")],
            generatedAt: date(2)
        ))
        defer {
            try? FileManager.default.removeItem(
                at: firstURL.deletingLastPathComponent()
            )
        }
        let firstContents = try String(contentsOf: firstURL, encoding: .utf8)

        let secondURL = try #require(IntentionCalendarExporter.exportFile(
            intentionTitle: "Write / with courage",
            aspirationTitle: nil,
            actions: [action(title: "Second")],
            generatedAt: date(2)
        ))
        defer {
            try? FileManager.default.removeItem(
                at: secondURL.deletingLastPathComponent()
            )
        }
        let secondContents = try String(contentsOf: secondURL, encoding: .utf8)
        let unchangedFirstContents = try String(contentsOf: firstURL, encoding: .utf8)

        #expect(firstURL.lastPathComponent == secondURL.lastPathComponent)
        #expect(firstURL != secondURL)
        #expect(secondContents.contains("SUMMARY:Second"))
        #expect(unchangedFirstContents == firstContents)
        #expect(unchangedFirstContents.contains("SUMMARY:First"))
    }
}
