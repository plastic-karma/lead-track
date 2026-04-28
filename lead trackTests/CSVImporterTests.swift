import Foundation
import Testing
@testable import lead_track

struct CSVImporterTests {
    // MARK: - Row Parsing

    @Test
    func parseRowsSplitsBasicCSV() {
        let rows = CSVImporter.parseRows("a,b,c\n1,2,3")
        #expect(rows.count == 2)
        #expect(rows[0] == ["a", "b", "c"])
        #expect(rows[1] == ["1", "2", "3"])
    }

    @Test
    func parseRowsHandlesQuotedComma() {
        let rows = CSVImporter.parseRows("\"a,b\",c")
        #expect(rows == [["a,b", "c"]])
    }

    @Test
    func parseRowsHandlesEscapedQuotes() {
        let rows = CSVImporter.parseRows("\"say \"\"hi\"\"\",x")
        #expect(rows == [["say \"hi\"", "x"]])
    }

    @Test
    func parseRowsHandlesQuotedNewline() {
        let rows = CSVImporter.parseRows("\"line1\nline2\",x")
        #expect(rows == [["line1\nline2", "x"]])
    }

    @Test
    func parseRowsIgnoresCarriageReturn() {
        let rows = CSVImporter.parseRows("a,b\r\n1,2\r\n")
        #expect(rows == [["a", "b"], ["1", "2"]])
    }

    @Test
    func parseRowsTrailingFieldWithoutNewline() {
        let rows = CSVImporter.parseRows("a,b,c")
        #expect(rows == [["a", "b", "c"]])
    }

    // MARK: - Header

    @Test
    func validHeaderRecognized() {
        let fields = CSVImporter.expectedHeader
            .split(separator: ",")
            .map(String.init)
        #expect(CSVImporter.isValidHeader(fields))
    }

    @Test
    func invalidHeaderRejected() {
        #expect(!CSVImporter.isValidHeader(["foo", "bar"]))
    }

    // MARK: - Timestamp Parsing

    @Test
    func parseTimestampRoundTripsExporterFormat() {
        let original = makeDate(2026, 4, 15, 10, 30, 0)
        let dateString = original.formatted(
            date: .numeric, time: .omitted
        )
        let timeString = original.formatted(
            date: .omitted, time: .standard
        )
        let parsed = CSVImporter.parseTimestamp(
            date: dateString, time: timeString
        )
        #expect(parsed == original)
    }

    @Test
    func parseTimestampReturnsNilForGarbage() {
        #expect(
            CSVImporter.parseTimestamp(
                date: "not a date", time: "12:00:00"
            ) == nil
        )
    }

    // MARK: - Helpers

    private func makeDate(
        _ year: Int, _ month: Int, _ day: Int,
        _ hour: Int, _ minute: Int, _ second: Int
    ) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = second
        return Calendar.current.date(from: components) ?? .now
    }
}
