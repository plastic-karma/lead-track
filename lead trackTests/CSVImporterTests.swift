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
    func headerConstantIsExpected() {
        #expect(
            CSVImporter.expectedHeader
                == "Metric,Project,Date,Start,End,Duration (s),Value,Type"
        )
    }

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
}
