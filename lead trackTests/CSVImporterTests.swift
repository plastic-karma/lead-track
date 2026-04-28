import Testing
@testable import lead_track

struct CSVImporterTests {
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
}
