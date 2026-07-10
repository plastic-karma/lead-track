import Foundation
import Testing
@testable import lead_track

struct CSVExporterTests {
    // MARK: - Escape

    @Test
    func escapePlainText() {
        #expect(CSVExporter.escape("hello") == "hello")
    }

    @Test
    func escapeTextWithComma() {
        #expect(CSVExporter.escape("a,b") == "\"a,b\"")
    }

    @Test
    func escapeTextWithQuotes() {
        #expect(CSVExporter.escape("say \"hi\"") == "\"say \"\"hi\"\"\"")
    }

    @Test
    func escapeTextWithNewline() {
        #expect(CSVExporter.escape("line1\nline2") == "\"line1\nline2\"")
    }

    @Test
    func escapeEmptyString() {
        #expect(CSVExporter.escape("") == "")
    }

    @Test
    func escapeNeutralizesFormulaLeaders() {
        // CWE-1236: a leading formula character would execute when the
        // export is opened in a spreadsheet.
        #expect(CSVExporter.escape("=SUM(A1)") == "'=SUM(A1)")
        #expect(CSVExporter.escape("@cmd") == "'@cmd")
        #expect(CSVExporter.escape("+1") == "'+1")
        #expect(CSVExporter.escape("-Zone 2") == "'-Zone 2")
    }

    @Test
    func escapeQuotesGuardedFieldWithComma() {
        #expect(CSVExporter.escape("=a,b") == "\"'=a,b\"")
    }

    // MARK: - Build CSV

    @Test
    func buildCSVIncludesHeader() {
        let csv = CSVExporter.buildCSV(from: [])
        #expect(csv.hasPrefix("Metric,Project,Date,Start,End,"))
    }

    @Test
    func buildCSVIncludesSessionRow() {
        let now = Date.now
        let session = Session(
            startedAt: now,
            endedAt: now.addingTimeInterval(60)
        )
        let csv = CSVExporter.buildCSV(from: [session])
        let lines = csv.components(separatedBy: "\n")
        #expect(lines.count == 2)
    }

    @Test
    func rowCarriesFixedFormatInstantsAndValues() throws {
        let started = Date(timeIntervalSince1970: 1_750_000_000)
        let metric = Metric(name: "Run", measurementType: .count)
        metric.unit = "km"
        let session = Session(
            metric: metric,
            startedAt: started,
            endedAt: started.addingTimeInterval(60),
            value: 2.5
        )

        let csv = CSVExporter.buildCSV(from: [session])
        let row = try #require(
            CSVImporter.parseRows(csv).last
        )

        #expect(row[CSVSchema.metric.index] == "Run")
        #expect(row[CSVSchema.start.index] == started.formatted(.iso8601))
        #expect(row[CSVSchema.end.index]
            == started.addingTimeInterval(60).formatted(.iso8601))
        #expect(row[CSVSchema.duration.index] == "60")
        #expect(row[CSVSchema.value.index] == "2.5")
        #expect(row[CSVSchema.type.index] == "count")
    }

    // MARK: - Filter by Scope

    #if canImport(SwiftData)
    @Test
    func filterByScopeAllReturnsEverything() {
        let s1 = Session(startedAt: .now, endedAt: .now)
        let s2 = Session(startedAt: .now, endedAt: .now)
        let result = CSVExporter.filterByScope(
            [s1, s2], scope: .all
        )
        #expect(result.count == 2)
    }
    #endif

    // MARK: - Filter by Time

    @Test
    func filterByTimeWithNilCutoffReturnsAll() {
        let s1 = Session(startedAt: .distantPast, endedAt: .now)
        let result = CSVExporter.filterByTime(
            [s1], cutoff: nil
        )
        #expect(result.count == 1)
    }

    @Test
    func filterByTimeExcludesOldSessions() {
        let old = Session(
            startedAt: .distantPast,
            endedAt: .distantPast
        )
        let recent = Session(
            startedAt: .now,
            endedAt: .now
        )
        let cutoff = Calendar.current.date(
            byAdding: .day, value: -7, to: .now
        )
        let result = CSVExporter.filterByTime(
            [old, recent], cutoff: cutoff
        )
        #expect(result.count == 1)
    }
}
