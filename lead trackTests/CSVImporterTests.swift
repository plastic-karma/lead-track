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
    func parseRowsNormalizesCRLF() {
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

    // MARK: - Round Trip

    private let anchor = Date(timeIntervalSince1970: 1_750_000_000)

    @Test
    func isoRowRoundTripsInstantsExactly() throws {
        let metric = Metric(name: "Reading", measurementType: .duration)
        let ended = anchor.addingTimeInterval(3600)
        let session = Session(metric: metric, startedAt: anchor, endedAt: ended)

        let rows = CSVImporter.parseRows(CSVExporter.buildCSV(from: [session]))
        let fields = try #require(rows.last)
        let parsed = try #require(
            ParsedRow(fields: fields, now: ended.addingTimeInterval(60))
        )

        #expect(parsed.metricName == "Reading")
        #expect(parsed.startedAt == anchor)
        #expect(parsed.endedAt == ended)
    }

    @Test
    func legacyLocaleRowStillParses() throws {
        // Old exports wrote the device locale's formats; a same-machine
        // parse must keep accepting them.
        let started = anchor
        let fields = legacyFields(
            started: started, ended: started.addingTimeInterval(600)
        )
        let parsed = try #require(
            ParsedRow(fields: fields, now: started.addingTimeInterval(7200))
        )
        #expect(parsed.startedAt == started)
        #expect(parsed.endedAt == started.addingTimeInterval(600))
    }

    @Test
    func legacyMidnightCrossingEndLandsOnTheNextDay() throws {
        // A 23:30–00:15 session exported by the old format carried only the
        // start's date plus a bare end clock; re-importing it must not
        // produce an end ~23h before the start.
        let day = Calendar.current.startOfDay(for: anchor)
        let started = day.addingTimeInterval(23 * 3600 + 30 * 60)
        let ended = started.addingTimeInterval(45 * 60)
        let fields = legacyFields(started: started, ended: ended)

        let parsed = try #require(
            ParsedRow(fields: fields, now: ended.addingTimeInterval(7200))
        )

        #expect(parsed.endedAt == ended)
        #expect(parsed.endedAt.map { $0 > parsed.startedAt } == true)
    }

    private func legacyFields(started: Date, ended: Date?) -> [String] {
        [
            "Reading",
            "",
            started.formatted(date: .numeric, time: .omitted),
            started.formatted(date: .omitted, time: .standard),
            ended?.formatted(date: .omitted, time: .standard) ?? "",
            "0",
            "",
            "duration"
        ]
    }

    // MARK: - Untrusted Input

    private func isoFields(
        start: Date,
        end: Date? = nil,
        value: String = ""
    ) -> [String] {
        [
            "Reading",
            "",
            "2025-06-15",
            CSVSchema.encodeInstant(start),
            end.map { CSVSchema.encodeInstant($0) } ?? "",
            "0",
            value,
            "count"
        ]
    }

    @Test
    func rejectsNonFiniteAndNegativeValues() {
        let now = anchor.addingTimeInterval(3600)
        for bad in ["nan", "inf", "-5"] {
            let fields = isoFields(start: anchor, value: bad)
            #expect(ParsedRow(fields: fields, now: now) == nil)
        }
    }

    @Test
    func keepsUnparseableValueAsNil() throws {
        let fields = isoFields(start: anchor, value: "not a number")
        let parsed = try #require(
            ParsedRow(fields: fields, now: anchor.addingTimeInterval(60))
        )
        #expect(parsed.value == nil)
    }

    @Test
    func rejectsFutureTimestamps() {
        let now = anchor
        #expect(ParsedRow(
            fields: isoFields(start: anchor.addingTimeInterval(86400)), now: now
        ) == nil)
        #expect(ParsedRow(
            fields: isoFields(start: anchor, end: anchor.addingTimeInterval(86400)),
            now: now
        ) == nil)
    }

    @Test
    func rejectsShortAndNamelessRows() {
        let now = anchor.addingTimeInterval(60)
        #expect(ParsedRow(fields: ["a", "b"], now: now) == nil)
        var nameless = isoFields(start: anchor)
        nameless[CSVSchema.metric.index] = "  "
        #expect(ParsedRow(fields: nameless, now: now) == nil)
    }

    // MARK: - Formula-Guard Names

    @Test
    func formulaGuardRoundTripsThroughImport() {
        #expect(CSVImporter.unescapedName("'=SUM(A1)") == "=SUM(A1)")
        #expect(CSVImporter.unescapedName("'-Zone 2") == "-Zone 2")
        // A genuine leading apostrophe not shielding a formula stays.
        #expect(CSVImporter.unescapedName("'quoted name") == "'quoted name")
        #expect(CSVImporter.unescapedName("plain") == "plain")
    }
}
